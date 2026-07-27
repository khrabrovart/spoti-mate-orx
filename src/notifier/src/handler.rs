use std::env;

use aws_sdk_ssm::Client as SsmClient;
use lambda_runtime::{Error, LambdaEvent};
use serde_json::{json, Value};
use tracing::{error, info};
use url::Url;

const SPOTIFY_AUTHORIZE_URL: &str = "https://accounts.spotify.com/authorize";
const SPOTIFY_SCOPES: &[&str] = &[
    "playlist-modify-private",
    "playlist-modify-public",
    "playlist-read-collaborative",
    "playlist-read-private",
    "user-follow-modify",
    "user-follow-read",
    "user-library-modify",
    "user-library-read",
];
const TELEGRAM_API_BASE: &str = "https://api.telegram.org";

pub async fn handle(event: LambdaEvent<Value>) -> Result<(), Error> {
    let account = event
        .payload
        .get("account")
        .and_then(Value::as_str)
        .ok_or_else(|| Error::from("missing or invalid 'account' in event payload"))?;

    info!(account, "starting notifier");

    let (chat_id_param, state) = match account {
        "primary" => ("TELEGRAM_PRIMARY_CHAT_ID_PARAM", "primary"),
        "secondary" => ("TELEGRAM_SECONDARY_CHAT_ID_PARAM", "secondary"),
        other => {
            return Err(Error::from(format!(
                "invalid 'account' in event payload: {other}"
            )))
        }
    };

    let config = aws_config::load_defaults(aws_config::BehaviorVersion::latest()).await;
    let ssm = SsmClient::new(&config);

    let bot_token = get_parameter(&ssm, &env::var("TELEGRAM_BOT_TOKEN_PARAM")?).await?;
    let chat_id = get_parameter(&ssm, &env::var(chat_id_param)?).await?;
    let spotify_client_id = get_parameter(&ssm, &env::var("SPOTIFY_CLIENT_ID_PARAM")?).await?;
    let redirect_uri = env::var("SPOTIFY_REDIRECT_URI")?;

    let authorize_url =
        build_authorize_url(&spotify_client_id, &redirect_uri, state, SPOTIFY_SCOPES)?;

    send_telegram_message(&bot_token, &chat_id, &authorize_url).await?;

    info!(account, "spotify authorization link sent via telegram");
    Ok(())
}

async fn get_parameter(ssm: &SsmClient, name: &str) -> Result<String, Error> {
    let response = ssm
        .get_parameter()
        .name(name)
        .with_decryption(true)
        .send()
        .await?;

    response
        .parameter()
        .and_then(|parameter| parameter.value())
        .map(str::to_owned)
        .ok_or_else(|| Error::from(format!("missing value for SSM parameter {name}")))
}

fn build_authorize_url(
    client_id: &str,
    redirect_uri: &str,
    state: &str,
    scopes: &[&str],
) -> Result<String, Error> {
    let mut url = Url::parse(SPOTIFY_AUTHORIZE_URL)?;
    url.query_pairs_mut()
        .append_pair("client_id", client_id)
        .append_pair("response_type", "code")
        .append_pair("redirect_uri", redirect_uri)
        .append_pair("state", state)
        .append_pair("scope", &scopes.join(" "));

    Ok(url.into())
}

fn escape_html_attr(value: &str) -> String {
    value.replace('&', "&amp;").replace('"', "&quot;")
}

fn build_telegram_message(authorize_url: &str) -> String {
    let authorize_url = escape_html_attr(authorize_url);

    format!(
        "<b>Spotify Authorization</b>\n
         Authorize the account to keep using SpotiMate, click the link below:\n\n\
         <a href=\"{authorize_url}\">Authorize Spotify</a>"
    )
}

async fn send_telegram_message(
    bot_token: &str,
    chat_id: &str,
    authorize_url: &str,
) -> Result<(), Error> {
    let client = reqwest::Client::new();
    let send_message_url = format!("{TELEGRAM_API_BASE}/bot{bot_token}/sendMessage");
    let text = build_telegram_message(authorize_url);

    let response = client
        .post(&send_message_url)
        .json(&json!({
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "HTML",
        }))
        .send()
        .await?;

    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().await.unwrap_or_default();
        error!(%status, %body, "telegram sendMessage request failed");
        return Err(Error::from(format!(
            "telegram sendMessage request failed with status {status}"
        )));
    }

    Ok(())
}
