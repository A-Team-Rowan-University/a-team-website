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

    let database_url = match env::var("DATABASE_URL") {
        Ok(url) => url,
        Err(e) => {
            error!("Could not read DATABASE_URL environment variable");
            return;
        },
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
                    "POST, GET, DELETE, OPTIONS"
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

            let http_response = match response {
                Ok(user_response) => {
                    match user_response {
                        models::UserResponse::OneUser(user) => rouille::Response::json(&user),
                        models::UserResponse::ManyUsers(users) => rouille::Response::json(&users),
                        models::UserResponse::NoResponse => rouille::Response::empty_204(),
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
            };

            http_response.with_additional_header("Access-Control-Allow-Origin", "*")
        }
    });
}

fn handle_request(
    request: &rouille::Request,
    database_connection: &MysqlConnection,
) -> Result<models::UserResponse, WebdevError> {
    router!(request,
        (GET) (/users) => {
            // NOTE: get_param does a right search, so any param that is the same as the end of
            // another param will be treated as the same. That is why '_exact' is at the end
            // See rouille lib.rs, line 694 (fn get_param in impl Request).
            // TODO: Find a way around this?
            handle_get(
                request.get_param("first_name_exact"),
                request.get_param("last_name_exact"),
                if let Some(p) = request.get_param("banner_id_exact") { Some(p.parse()?) } else { None },
                if let Some(p) = request.get_param("has_email") { Some(p.parse()?) } else { None },
                request.get_param("email_exact"),
                database_connection
            ).map(|s| models::UserResponse::ManyUsers(s))
        },
        (POST) (/users) => {
            let request_body = request.data().ok_or(WebdevError::new(WebdevErrorKind::Format))?;
            let new_user: models::NewUser = serde_json::from_reader(request_body)?;

            handle_insert(new_user, database_connection).map(|s| models::UserResponse::OneUser(s))
        },
        (POST) (/users/{id: u64}) => {
            let request_body = request.data().ok_or(WebdevError::new(WebdevErrorKind::Format))?;
            let update_user: models::PartialUser = serde_json::from_reader(request_body)?;
            handle_update(id, update_user, database_connection).map(|_| models::UserResponse::NoResponse)
        },
        (DELETE) (/users/{id: u64}) => {
            handle_delete(id, database_connection).map(|_| models::UserResponse::NoResponse)
        },
        _ => Err(WebdevError::new(WebdevErrorKind::NotFound))
    )
}

fn handle_get(
    first_name_filter: Option<String>,
    last_name_filter: Option<String>,
    banner_id_filter: Option<u32>,
    has_email_filter: Option<bool>,
    email_filter: Option<String>,
    database_connection: &MysqlConnection,
) -> Result<models::UserList, WebdevError> {
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

    if let Some(p) = has_email_filter {
        if p {
            trace!("Not null!");
            users_query = users_query.filter(users::email.is_not_null());
        } else {
            trace!("Null!");
            users_query = users_query.filter(users::email.is_null());
        }
    }

    if let Some(p) = email_filter {
        users_query = users_query.filter(users::email.eq(p));
    }

    trace!("Executing query: {}" , diesel::debug_query(&users_query));

    let all_users = users_query.load::<models::User>(database_connection)?;
    let user_list = models::UserList {
        users: all_users
    };

    Ok(user_list)
}

fn handle_insert(
    new_user: models::NewUser,
    database_connection: &MysqlConnection,
) -> Result<models::User, WebdevError> {

    diesel::insert_into(users::table)
        .values(new_user)
        .execute(database_connection)?;

    let mut inserted_users = users::table
        .filter(diesel::dsl::sql("id = LAST_INSERT_ID()"))
        .load::<models::User>(database_connection)?;

    match inserted_users.pop() {
        Some(user) => Ok(user),
        None => Err(WebdevError::new(WebdevErrorKind::Database)),
    }
}

fn handle_update(id: u64, user: models::PartialUser, database_connection: &MysqlConnection) -> Result<(), WebdevError> {
    diesel::update(users::table).filter(users::id.eq(id)).set(&user).execute(database_connection)?;

    Ok(())
}

fn handle_delete(id: u64, database_connection: &MysqlConnection) -> Result<(), WebdevError> {
    diesel::delete(users::table.filter(users::id.eq(id))).execute(database_connection)?;

    Ok(())
}
