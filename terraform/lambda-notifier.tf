data "archive_file" "notifier_lambda_zip" {
  type        = "zip"
  source_file = "../notifier-lambda/bootstrap"
  output_path = "notifier_lambda.zip"
}

resource "aws_lambda_function" "notifier_lambda" {
  filename      = data.archive_file.notifier_lambda_zip.output_path
  function_name = "${local.app_name}-notifier"
  role          = aws_iam_role.notifier_lambda_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  timeout       = 30
  memory_size   = 128
  architectures = ["arm64"]

  source_code_hash = data.archive_file.notifier_lambda_zip.output_base64sha256

  environment {
    variables = {
      TELEGRAM_BOT_TOKEN_PARAM          = data.aws_ssm_parameter.telegram_bot_token.name
      TELEGRAM_PRIMARY_CHAT_ID_PARAM    = data.aws_ssm_parameter.telegram_primary_chat_id.name
      TELEGRAM_SECONDARY_CHAT_ID_PARAM  = data.aws_ssm_parameter.telegram_secondary_chat_id.name
      SPOTIFY_CLIENT_ID_PARAM  = data.aws_ssm_parameter.spotify_client_id.name
      SPOTIFY_REDIRECT_URI     = "${trimsuffix(aws_apigatewayv2_stage.default.invoke_url, "/")}/callback"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.notifier_lambda_basic_execution,
    aws_iam_role_policy.notifier_lambda_ssm,
    aws_cloudwatch_log_group.notifier_lambda_logs
  ]
}

resource "aws_iam_role" "notifier_lambda_role" {
  name = "${local.app_name}-notifier-lambda-role"

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

resource "aws_iam_role_policy_attachment" "notifier_lambda_basic_execution" {
  role       = aws_iam_role.notifier_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_kms_key" "ssm" {
  key_id = "alias/aws/ssm"
}

resource "aws_iam_role_policy" "notifier_lambda_ssm" {
  name = "${local.app_name}-notifier-ssm-read"
  role = aws_iam_role.notifier_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter"]
        Resource = [
          data.aws_ssm_parameter.telegram_bot_token.arn,
          data.aws_ssm_parameter.telegram_primary_chat_id.arn,
          data.aws_ssm_parameter.telegram_secondary_chat_id.arn,
          data.aws_ssm_parameter.spotify_client_id.arn,
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [data.aws_kms_key.ssm.arn]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "notifier_lambda_logs" {
  name              = "/aws/lambda/${local.app_name}-notifier"
  retention_in_days = 14
}
