data "aws_ssm_parameter" "telegram_bot_token" {
  name = "/${local.app_name}/telegram/bot-token"
}

data "aws_ssm_parameter" "telegram_chat_id" {
  name = "/${local.app_name}/telegram/chat-id"
}

data "aws_ssm_parameter" "spotify_client_id" {
  name = "/${local.app_name}/spotify/client-id"
}
