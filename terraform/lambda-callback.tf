data "archive_file" "callback_lambda_zip" {
  type        = "zip"
  source_file = "../callback-lambda/bootstrap"
  output_path = "callback_lambda.zip"
}

resource "aws_lambda_function" "callback_lambda" {
  filename      = data.archive_file.callback_lambda_zip.output_path
  function_name = "${local.app_name}-callback"
  role          = aws_iam_role.callback_lambda_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  timeout       = 10
  memory_size   = 128
  architectures = ["arm64"]

  source_code_hash = data.archive_file.callback_lambda_zip.output_base64sha256

  depends_on = [
    aws_iam_role_policy_attachment.callback_lambda_basic_execution,
    aws_cloudwatch_log_group.callback_lambda_logs
  ]
}

resource "aws_iam_role" "callback_lambda_role" {
  name = "${local.app_name}-callback-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "callback_lambda_basic_execution" {
  role       = aws_iam_role.callback_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "callback_lambda_logs" {
  name              = "/aws/lambda/${local.app_name}-callback"
  retention_in_days = 14
}

