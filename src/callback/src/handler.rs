use std::env;

use aws_sdk_ssm::{types::ParameterType, Client as SsmClient};
use lambda_http::{Body, Error, Request, RequestExt, Response};
use serde::Deserialize;
use tracing::{error, info};

const SPOTIFY_TOKEN_URL: &str = "https://accounts.spotify.com/api/token";

pub async fn handle(request: Request) -> Result<Response<Body>, Error> {
    let query_params = request.query_string_parameters();

    let code = match query_params.first("code") {
        Some(code) => code,
        None => {
            return missing_code_response(
                query_params.first("error"),
                query_params.first("error_description"),
            )
        }
    };

    let state =
        match query_params.first("state") {
            Some(state) => state,
            None => return error_response(
                "Spotify authorization failed. The callback URL is missing the state parameter.",
            ),
        };

    let refresh_token_param = match state {
        "primary" => env::var("SPOTIFY_PRIMARY_REFRESH_TOKEN_PARAM")?,
        "secondary" => env::var("SPOTIFY_SECONDARY_REFRESH_TOKEN_PARAM")?,
        other => {
            return error_response(&format!(
                "Spotify authorization failed. The account identifier in the link is \"{other}\"."
            ))
        }
    };

    let config = aws_config::load_defaults(aws_config::BehaviorVersion::latest()).await;
    let ssm = SsmClient::new(&config);

    let client_id = get_parameter(&ssm, &env::var("SPOTIFY_CLIENT_ID_PARAM")?).await?;
    let client_secret = get_parameter(&ssm, &env::var("SPOTIFY_CLIENT_SECRET_PARAM")?).await?;
    let redirect_uri = env::var("SPOTIFY_REDIRECT_URI")?;

    let refresh_token =
        exchange_code_for_refresh_token(&client_id, &client_secret, code, &redirect_uri).await?;

    ssm.put_parameter()
        .name(&refresh_token_param)
        .value(&refresh_token)
        .r#type(ParameterType::SecureString)
        .overwrite(true)
        .send()
        .await?;

    info!(state, "refresh token saved to SSM");
    success_response()
}

fn missing_code_response(
    spotify_error: Option<&str>,
    spotify_error_description: Option<&str>,
) -> Result<Response<Body>, Error> {
    if let Some(error) = spotify_error {
        let message = match (error, spotify_error_description) {
            ("access_denied", _) => {
                "Spotify authorization failed. Access was declined on the Spotify permission screen."
            }
            (_, Some(description)) => {
                return error_response(&format!(
                    "Spotify authorization failed. Spotify returned error \"{error}\": {description}"
                ));
            }
            _ => {
                return error_response(&format!(
                    "Spotify authorization failed. Spotify returned error \"{error}\"."
                ));
            }
        };

        return error_response(message);
    }

    error_response(
        "Spotify authorization failed. Spotify did not return an authorization code. \
         Please complete the authorization process.",
    )
}

fn success_response() -> Result<Response<Body>, Error> {
    text_response(200, "Spotify authorization complete successfully.")
}

fn error_response(message: &str) -> Result<Response<Body>, Error> {
    text_response(400, message)
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

async fn exchange_code_for_refresh_token(
    client_id: &str,
    client_secret: &str,
    code: &str,
    redirect_uri: &str,
) -> Result<String, Error> {
    let client = reqwest::Client::new();
    let response = client
        .post(SPOTIFY_TOKEN_URL)
        .form(&[
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", redirect_uri),
            ("client_id", client_id),
            ("client_secret", client_secret),
        ])
        .send()
        .await?;

    let status = response.status();
    let body = response.text().await?;

    if !status.is_success() {
        error!(%status, %body, "spotify token exchange failed");
        return Err(Error::from(format!(
            "spotify token exchange failed with status {status}"
        )));
    }

    let token_response: TokenResponse = serde_json::from_str(&body).map_err(|err| {
        error!(%body, %err, "failed to parse spotify token response");
        Error::from(format!("failed to parse spotify token response: {err}"))
    })?;

    token_response.refresh_token.ok_or_else(|| {
        error!(%body, "spotify token response missing refresh_token");
        Error::from("spotify token response missing refresh_token")
    })
}

fn text_response(status: u16, body: &str) -> Result<Response<Body>, Error> {
    Ok(Response::builder()
        .status(status)
        .header("content-type", "text/plain; charset=utf-8")
        .body(Body::Text(body.to_owned()))?)
}

#[derive(Debug, Deserialize)]
struct TokenResponse {
    refresh_token: Option<String>,
}
