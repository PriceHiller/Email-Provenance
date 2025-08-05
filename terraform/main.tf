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
}

resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = "pushd '${local.lambda_root}' && uv export --frozen --no-dev --no-editable -o '${local.lambda_root}/requirements.ignore.txt' && uv pip install --no-installer-metadata --no-compile-bytecode --python-platform=x86_64-manylinux2014 --python 3.13 --target package -r '${local.lambda_root}/requirements.ignore.txt' && popd"
  }

  triggers = {
    dependencies_versions           = filemd5("${local.lambda_root}/uv.lock")
    source_versions_init            = filemd5("${local.lambda_root}/app/__init__.py")
    source_versions_handler         = filemd5("${local.lambda_root}/app/handler.py")
    source_versions_main            = filemd5("${local.lambda_root}/app/main.py")
    source_versions_scrape          = filemd5("${local.lambda_root}/app/scrape.py")
    source_versions_upload_selector = filemd5("${local.lambda_root}/app/upload_selector.py")
  }
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

data "archive_file" "lambda_source" {
  depends_on = [null_resource.install_dependencies]
  excludes = [
    "__pycache__",
    ".venv",
    "uv.lock"
  ]

  source_dir  = local.lambda_root
  output_path = "${random_uuid.lambda_src_hash.result}.ignore.zip"
  type        = "zip"
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

resource "aws_lambda_function" "lambda" {
  function_name    = "my_function"
  role             = aws_iam_role.example.arn
  filename         = data.archive_file.lambda_source.output_path
  source_code_hash = data.archive_file.lambda_source.output_base64sha256

  handler = "app.main.handler"
  runtime = "python3.13"

  # tags =
}
