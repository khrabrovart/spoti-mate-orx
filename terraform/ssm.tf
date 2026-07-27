resource "aws_ssm_parameter" "telegram_bot_token" {
  name  = "/${local.app_name}/telegram/bot-token"
  type  = "SecureString"
  value = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "telegram_primary_chat_id" {
  name  = "/${local.app_name}/telegram/primary-chat-id"
  type  = "SecureString"
  value = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "telegram_secondary_chat_id" {
  name  = "/${local.app_name}/telegram/secondary-chat-id"
  type  = "SecureString"
  value = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "spotify_client_id" {
  name  = "/${local.app_name}/spotify/client-id"
  type  = "SecureString"
  value = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "spotify_client_secret" {
  name  = "/${local.app_name}/spotify/client-secret"
  type  = "SecureString"
  value = "PLACEHOLDER"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "spotify_primary_refresh_token" {
  name  = "/${local.app_name}/spotify/primary-refresh-token"
  type  = "SecureString"
  value = "pending-oauth"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "spotify_secondary_refresh_token" {
  name  = "/${local.app_name}/spotify/secondary-refresh-token"
  type  = "SecureString"
  value = "pending-oauth"

  lifecycle {
    ignore_changes = [value]
  }
}
