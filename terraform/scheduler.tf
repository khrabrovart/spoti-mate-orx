resource "aws_scheduler_schedule_group" "notifier" {
  name = "${local.app_name}-notifier"
}

resource "aws_iam_role" "scheduler_role" {
  name = "${local.app_name}-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "scheduler_invoke_notifier" {
  name = "${local.app_name}-scheduler-invoke-notifier"
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [aws_lambda_function.notifier_lambda.arn]
      }
    ]
  })
}

resource "aws_scheduler_schedule" "notifier_primary" {
  name       = "${local.app_name}-notifier-primary"
  group_name = aws_scheduler_schedule_group.notifier.name

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(150 days)"

  target {
    arn      = aws_lambda_function.notifier_lambda.arn
    role_arn = aws_iam_role.scheduler_role.arn
    input    = jsonencode({ value = "primary" })
  }
}

resource "aws_scheduler_schedule" "notifier_secondary" {
  name       = "${local.app_name}-notifier-secondary"
  group_name = aws_scheduler_schedule_group.notifier.name

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(150 days)"

  target {
    arn      = aws_lambda_function.notifier_lambda.arn
    role_arn = aws_iam_role.scheduler_role.arn
    input    = jsonencode({ value = "secondary" })
  }
}

resource "aws_lambda_permission" "scheduler_invoke_notifier_primary" {
  statement_id  = "AllowEventBridgeSchedulerInvokePrimary"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notifier_lambda.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.notifier_primary.arn
}

resource "aws_lambda_permission" "scheduler_invoke_notifier_secondary" {
  statement_id  = "AllowEventBridgeSchedulerInvokeSecondary"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notifier_lambda.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.notifier_secondary.arn
}
