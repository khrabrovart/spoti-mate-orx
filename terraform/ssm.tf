data "aws_ssm_parameter" "telegram_bot_token" {
  name = "/${local.app_name}/telegram/bot-token"
}

data "aws_ssm_parameter" "telegram_primary_chat_id" {
  name = "/${local.app_name}/telegram/primary-chat-id"
}

data "aws_ssm_parameter" "telegram_secondary_chat_id" {
  name = "/${local.app_name}/telegram/secondary-chat-id"
}

data "aws_ssm_parameter" "spotify_client_id" {
  name = "/${local.app_name}/spotify/client-id"
}

data "aws_ssm_parameter" "spotify_client_secret" {
  name = "/${local.app_name}/spotify/client-secret"
}

data "aws_ssm_parameter" "spotify_primary_refresh_token" {
  name = "/${local.app_name}/spotify/primary-refresh-token"
}

data "aws_ssm_parameter" "spotify_secondary_refresh_token" {
  name = "/${local.app_name}/spotify/secondary-refresh-token"
}
