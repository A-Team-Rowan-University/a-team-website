#[macro_use]
extern crate diesel;

use std::env;
use std::error::Error;
use std::sync::Mutex;

use log::debug;
use log::error;
use log::info;
use log::trace;
use log::warn;

use diesel::expression::AsExpression;
use diesel::prelude::*;
use diesel::query_builder::AsQuery;
use diesel::MysqlConnection;

use rouille::router;

use serde;
use serde_json;

use dotenv::dotenv;

use self::errors::WebdevError;
use self::errors::WebdevErrorKind;
use self::schema::users;

mod errors;
mod models;
mod schema;

fn main() {
    dotenv().ok();

    simplelog::TermLogger::init(simplelog::LevelFilter::Trace, simplelog::Config::default())
        .unwrap();

    info!("Connecting to database");

    let database_url = env::var("DATABASE_URL").expect("DATABSE_URL needs to be set");

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
            request.url(),
            request.remote_addr()
        );

        let current_connection = match connection_mutex.lock() {
            Ok(c) => c,
            Err(_e) => {
                error!("Could not lock database");
                return rouille::Response::from(WebdevError::new(WebdevErrorKind::Database));
            }
        };

        let response = handle_request(request, &current_connection);

        match response {
            Ok(json) => {
                if let Some(j) = json {
                    rouille::Response::json(&j)
                } else {
                    rouille::Response::empty_204()
                }
            }
            Err(e) => {
                if let Some(err_source) = e.source() {
                    error!("Error processing request: {}", err_source);
                } else {
                    error!("Error processing request");
                }

                rouille::Response::from(e)
            }
        }
    });
}

fn handle_request(
    request: &rouille::Request,
    database_connection: &MysqlConnection,
) -> Result<Option<String>, WebdevError> {
    router!(request,
        (GET) (/users) => {
            handle_get(
                request.get_param("first_name"),
                request.get_param("last_name"),
                if let Some(p) = request.get_param("banner_id") { Some(p.parse()?) } else { None },
                request.get_param("email"),
                database_connection
            ).map(|s| Some(s))
        },
        (POST) (/users) => {
            let request_body = request.data().ok_or(WebdevError::new(WebdevErrorKind::Format))?;
            let new_user: models::NewUser = serde_json::from_reader(request_body)?;

            handle_insert(new_user, database_connection).map(|s| Some(s))
        },
        (POST) (/users/{id: u64}) => {
            let request_body = request.data().ok_or(WebdevError::new(WebdevErrorKind::Format))?;
            let update_user: models::PartialUser = serde_json::from_reader(request_body)?;
            handle_update(id, update_user, database_connection).map(|_| None)
        },
        (DELETE) (/users/{id: u64}) => {
            handle_delete(id, database_connection).map(|_| None)
        },
        _ => Err(WebdevError::new(WebdevErrorKind::NotFound))
    )
}

fn handle_get(
    first_name_filter: Option<String>,
    last_name_filter: Option<String>,
    banner_id_filter: Option<u32>,
    email_filter: Option<String>,
    database_connection: &MysqlConnection,
) -> Result<String, WebdevError> {
    let mut users_query = users::table.as_query().into_boxed();

    if let Some(p) = first_name_filter {
        users_query = users_query.filter(users::first_name.eq(p));
    }

    if let Some(p) = last_name_filter {
        users_query = users_query.filter(users::last_name.eq(p));
    }

    if let Some(p) = banner_id_filter {
        users_query = users_query.filter(users::banner_id.eq(p));
    }

    if let Some(p) = email_filter {
        users_query = users_query.filter(users::email.eq(p));
    }

    let all_users = users_query.load::<models::User>(database_connection)?;
    Ok(serde_json::to_string(&all_users)?)
}

fn handle_insert(
    new_user: models::NewUser,
    database_connection: &MysqlConnection,
) -> Result<String, WebdevError> {

    diesel::insert_into(users::table)
        .values(new_user)
        .execute(database_connection)?;

    let inserted_user = users::table
        .filter(diesel::dsl::sql("id = LAST_INSERT_ID()"))
        .load::<models::User>(database_connection)?;

    Ok(serde_json::to_string(&inserted_user)?)
}

fn handle_update(id: u64, user: models::PartialUser, database_connection: &MysqlConnection) -> Result<(), WebdevError> {
    diesel::update(users::table).filter(users::id.eq(id)).set(&user).execute(database_connection)?;

    Ok(())
}

fn handle_delete(id: u64, database_connection: &MysqlConnection) -> Result<(), WebdevError> {
    diesel::delete(users::table.filter(users::id.eq(id))).execute(database_connection)?;

    Ok(())
}
