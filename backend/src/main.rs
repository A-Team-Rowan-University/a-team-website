use std::env;
use std::sync::Mutex;

use log::debug;
use log::error;
use log::info;
use log::trace;
use log::warn;

use diesel::prelude::*;
use diesel::MysqlConnection;

use dotenv::dotenv;

use self::errors::WebdevError;
use self::errors::WebdevErrorKind;


use self::users::models::UserRequest;
use self::users::requests::handle_user;

fn main() {
    dotenv().ok();

    simplelog::TermLogger::init(simplelog::LevelFilter::Trace, simplelog::Config::default())
        .unwrap();

    info!("Connecting to database");

    let database_url = match env::var("DATABASE_URL") {
        Ok(url) => url,
        Err(e) => {
            error!("Could not read DATABASE_URL environment variable");
            return;
        }
    };

    debug!("Connecting to {}", database_url);

    let connection = match MysqlConnection::establish(&database_url) {
        Ok(c) => c,
        Err(e) => {
            error!("Could not connect to database: {}", e);
            return;
        }
    };

    debug!("Connected to database");

    let connection_mutex = Mutex::new(connection);

    info!("Starting server on 0.0.0.0:8000");

    rouille::start_server("0.0.0.0:8000", move |request| {
        debug!(
            "Handling request {} {} from {}",
            request.method(),
            request.raw_url(),
            request.remote_addr()
        );

        if request.method() == "OPTIONS" {
            rouille::Response::text("")
                .with_additional_header(
                    "Access-Control-Allow-Methods",
                    "POST, GET, DELETE, OPTIONS",
                )
                .with_additional_header("Access-Control-Allow-Origin", "*")
                .with_additional_header("Access-Control-Allow-Headers", "X-PINGOTHER, Content-Type")
                .with_additional_header("Access-Control-Max-Age", "86400")
        } else {
            let current_connection = match connection_mutex.lock() {
                Ok(c) => c,
                Err(_e) => {
                    error!("Could not lock database");
                    return rouille::Response::from(WebdevError::new(WebdevErrorKind::Database));
                }
            };

            let response = handle_request(request, &current_connection);

            response.with_additional_header("Access-Control-Allow-Origin", "*")
        }
    });
}

fn handle_request(
    request: &rouille::Request,
    database_connection: &MysqlConnection,
) -> rouille::Response {
    if let Some(user_request) = request.remove_prefix("/users") {
        match UserRequest::from_rouille(&user_request) {
            Err(err) => rouille::Response::from(err),
            Ok(user_request) => match handle_user(user_request, database_connection) {
                Ok(user_response) => user_response.to_rouille(),
                Err(err) => rouille::Response::from(err),
            },
        }
    } else {
        rouille::Response::empty_404()
    }
}
