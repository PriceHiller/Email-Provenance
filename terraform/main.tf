terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.2.0"
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
  dynamo_tablename = "ekim-dkim-records"
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

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 7
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_lambda_function" "lambda" {
  function_name    = "ekim-dkim"
  role             = aws_iam_role.lambda_role.arn
  filename         = data.archive_file.lambda_source.output_path
  source_code_hash = data.archive_file.lambda_source.output_base64sha256
  environment {
    variables = {
      DYNAMO_TABLE = local.dynamo_tablename
    }
  }
  layers = [
    aws_lambda_layer_version.dependencies.arn
  ]

  handler = "app.main.router"
  runtime = "python3.13"
}

module "eventbridge" {
  source = "terraform-aws-modules/eventbridge/aws"

  create_bus = false

  rules = {
    crons = {
      description         = "Trigger ekim dkim rescrape every 5 minutes"
      schedule_expression = "rate(5 minutes)"
    }
  }

  targets = {
    crons = [
      {
        name  = "trigger-scrape-${aws_lambda_function.lambda.function_name}"
        arn   = "${aws_lambda_function.lambda.arn}"
        input = jsonencode({"endpoint": "rescrape"})
      }
    ]
  }
}

resource "aws_dynamodb_table" "lambda_table" {
  name           = "${local.dynamo_tablename}"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "domain"

  attribute {
    name = "domain"
    type = "S"
  }
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

data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    effect = "Allow"
    resources = [
      aws_dynamodb_table.lambda_table.arn
    ]
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem"
    ]
  }

  statement {
    effect = "Allow"
    resources = [
      "arn:aws:logs:*:*:*"
    ]
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
  }
}

resource "aws_iam_policy" "dynamodb_lambda_policy" {
  name = "${local.dynamo_tablename}-${aws_lambda_function.lambda.function_name}"
  description = "Allow access to dynamo db"
  policy = data.aws_iam_policy_document.lambda_policy_document.json
}

resource "aws_iam_role_policy_attachment" "lambda_attachements" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_lambda_policy.arn
} 

resource "aws_iam_role" "lambda_role" {
  name               = "ekim-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

