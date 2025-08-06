terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
  required_version = ">= 1.2"
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

locals {
  lambda_root = "${path.module}/../lambda"
  lambda_runtime = "python3.13"
  deps_root   = "${path.module}/pkg-root.ignore"
  lambda_src_files = fileset(local.lambda_root, "**")
  lambda_src_hash = md5(join("", [
    for f in local.lambda_src_files : filemd5("${local.lambda_root}/${f}")
  ]))
}

resource "random_uuid" "lambda_src_hash" {
  keepers = {
    for filename in setunion(
      fileset(local.lambda_root, "app/__init__.py"),
      fileset(local.lambda_root, "app/handler.py"),
      fileset(local.lambda_root, "app/main.py"),
      fileset(local.lambda_root, "app/scrape.py"),
      fileset(local.lambda_root, "app/upload_selector.py"),
      fileset(local.lambda_root, "uv.lock")
    ) :
    filename => filemd5("${local.lambda_root}/${filename}")
  }
}

resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = <<-EOC
      uv export --frozen --no-dev --no-editable --project='${local.lambda_root}' -o 'requirements.ignore.txt'
      mkdir -p '${local.deps_root}/python'
      uv pip install --no-installer-metadata --no-compile-bytecode --python-platform=x86_64-manylinux2014 --python 3.13 --target '${local.deps_root}/python' -r 'requirements.ignore.txt'
    EOC
  }

  triggers = {
    run_always = local.lambda_src_hash
  }
}

data "archive_file" "lambda_deps" {
  depends_on  = [null_resource.install_dependencies]
  source_dir  = local.deps_root
  output_path = "${random_uuid.lambda_src_hash.result}-package.ignore.zip"
  type        = "zip"
}


resource "aws_lambda_layer_version" "dependencies" {
  layer_name               = "dependencies"
  filename                 = data.archive_file.lambda_deps.output_path
  source_code_hash         = data.archive_file.lambda_deps.output_base64sha256
  description              = "Common dependencies for Lambda functions"
  compatible_runtimes      = ["python3.13"]
  compatible_architectures = ["x86_64", "arm64"]
  lifecycle {
    create_before_destroy = true
  }
}

data "archive_file" "lambda_source" {
  excludes = [
    "__pycache__",
    ".venv",
    "uv.lock",
    "app/*__pycache__",
     "**__pycache__",
     "app/__pycache__"
  ]

  source_dir  = local.lambda_root
  output_path = "${random_uuid.lambda_src_hash.result}-app.ignore.zip"
  type        = "zip"
}



resource "aws_lambda_function" "lambda" {
  function_name    = "my_function"
  role             = aws_iam_role.example.arn
  filename         = data.archive_file.lambda_source.output_path
  source_code_hash = data.archive_file.lambda_source.output_base64sha256
  layers = [
    aws_lambda_layer_version.dependencies.arn
  ]

  handler = "app.main.handler"
  runtime = "python3.13"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "example" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

