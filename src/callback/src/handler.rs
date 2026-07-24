use lambda_http::{Body, Error, Request, RequestExt, Response};
use tracing::info;

pub async fn handle(request: Request) -> Result<Response<Body>, Error> {
    let query_params = request.query_string_parameters();

    for (name, value) in query_params.iter() {
        info!(param = name, value, "received spotify redirect parameter");
    }

    Ok(Response::builder().status(200).body(Body::Empty)?)
}
