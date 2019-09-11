#[macro_use]
extern crate diesel_migrations;

extern crate diesel;

use std::env;
use std::thread;
use std::time;

use log::debug;
use log::error;
use log::info;
use log::warn;

use diesel::r2d2::ConnectionManager;
use diesel::MysqlConnection;
use r2d2::Pool;

use dotenv::dotenv;

use webdev_lib::errors::Error;
use webdev_lib::errors::ErrorKind;

use webdev_lib::users::models::UserRequest;
use webdev_lib::users::requests::handle_user;

use webdev_lib::permissions::models::{
    PermissionRequest, UserPermissionRequest,
};
use webdev_lib::permissions::requests::validate_token;
use webdev_lib::permissions::requests::{
    handle_permission, handle_user_permission,
};

use webdev_lib::chemicals::models::{
    ChemicalInventoryRequest, ChemicalRequest,
};
use webdev_lib::chemicals::requests::{
    handle_chemical, handle_chemical_inventory,
};

use webdev_lib::tests::question_categories::models::QuestionCategoryRequest;
use webdev_lib::tests::question_categories::requests::handle_question_category;
use webdev_lib::tests::questions::models::QuestionRequest;
use webdev_lib::tests::questions::requests::handle_question;
use webdev_lib::tests::test_sessions::models::TestSessionRequest;
use webdev_lib::tests::test_sessions::requests::handle_test_session;
use webdev_lib::tests::tests::models::TestRequest;
use webdev_lib::tests::tests::requests::handle_test;

embed_migrations!("./webdev_lib/migrations");

pub fn init_database(
    url: &str,
) -> Result<Pool<ConnectionManager<MysqlConnection>>, Error> {
    info!("Connecting to database");
    let manager = ConnectionManager::new(url);

    let pool = Pool::builder().max_size(15).build(manager);

    let pool = match pool {
        Ok(p) => p,
        Err(e) => {
            return Err(Error::with_source(ErrorKind::Database, Box::new(e)))
        }
    };

    info!("Running migrations");
    if let Err(e) = embedded_migrations::run(&pool.get()?) {
        warn!("Could not run migrations: {}", e);
    }

    Ok(pool)
}

fn main() {
    dotenv().ok();

    let logging_config = simplelog::ConfigBuilder::new()
        .add_filter_ignore("hyper".to_string())
        .add_filter_ignore("rustls".to_string())
        .build();

    simplelog::SimpleLogger::init(
        simplelog::LevelFilter::Trace,
        logging_config,
    )
    .unwrap();

    info!("Connecting to database");

    let database_url = match env::var("DATABASE_URL") {
        Ok(url) => url,
        Err(_e) => {
            error!("Could not read DATABASE_URL environment variable");
            return;
        }
    };

    debug!("Connecting to {}", database_url);

    let connection_pool = loop {
        match init_database(&database_url) {
            Ok(c) => break c,
            Err(e) => {
                warn!("Could not connect to database: {}", e);
                info!("Retrying in a second");
                thread::sleep(time::Duration::from_secs(1));
            }
        }
    };

    info!("Connected to database");

    info!("Starting server on 0.0.0.0:8000");

    rouille::start_server("0.0.0.0:8000", move |request| {
        debug!(
            "Handling request {} {} from {}",
            request.method(),
            request.raw_url(),
            request.remote_addr(),
        );

        if request.method() == "OPTIONS" {
            rouille::Response::text("")
                .with_additional_header(
                    "Access-Control-Allow-Methods",
                    "POST, GET, DELETE, OPTIONS, PUT",
                )
                .with_additional_header("Access-Control-Allow-Origin", "*")
                .with_additional_header(
                    "Access-Control-Allow-Headers",
                    "X-PINGOTHER, Content-Type, id_token",
                )
                .with_additional_header("Access-Control-Max-Age", "86400")
        } else {
            let current_connection = match connection_pool.get() {
                Ok(c) => c,
                Err(_e) => {
                    error!("Could not lock database");
                    return rouille::Response::from(Error::new(
                        ErrorKind::Database,
                    ));
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
    let requested_user = if let Some(id_token) = request.header("id_token") {
        if request.url() == "/permission/first" {
            return match handle_permission(
                PermissionRequest::FirstPermission(id_token.to_string()),
                None,
                database_connection,
            ) {
                Ok(permission_response) => permission_response.to_rouille(),
                Err(err) => rouille::Response::from(err),
            };
        }

        match validate_token(id_token, database_connection) {
            Ok(user) => Some(user),
            Err(e) => {
                warn!("Failed to verify user: {}", e.to_string_with_source());
                return rouille::Response::from(e);
            }
        }
    } else {
        None
    };

    if let Some(user_request) = request.remove_prefix("/users") {
        match UserRequest::from_rouille(&user_request) {
            Err(err) => rouille::Response::from(err),
            Ok(user_request) => {
                match handle_user(
                    user_request,
                    requested_user,
                    database_connection,
                ) {
                    Ok(user_response) => user_response.to_rouille(),
                    Err(err) => rouille::Response::from(err),
                }
            }
        }
    } else if let Some(permission_request) =
        request.remove_prefix("/permission")
    {
        match PermissionRequest::from_rouille(&permission_request) {
            Err(err) => rouille::Response::from(err),
            Ok(permission_request) => {
                match handle_permission(
                    permission_request,
                    requested_user,
                    database_connection,
                ) {
                    Ok(permission_response) => permission_response.to_rouille(),
                    Err(err) => rouille::Response::from(err),
                }
            }
        }
    } else if let Some(user_permission_request) =
        request.remove_prefix("/user_permission")
    {
        match UserPermissionRequest::from_rouille(&user_permission_request) {
            Err(err) => rouille::Response::from(err),
            Ok(user_permission_request) => match handle_user_permission(
                user_permission_request,
                requested_user,
                database_connection,
            ) {
                Ok(user_permission_response) => {
                    user_permission_response.to_rouille()
                }
                Err(err) => rouille::Response::from(err),
            },
        }
    } else if let Some(chem_inventory_request_url) =
        request.remove_prefix("/chemical_inventory")
    {
        match ChemicalInventoryRequest::from_rouille(
            &chem_inventory_request_url,
        ) {
            Err(err) => rouille::Response::from(err),
            Ok(chem_inventory_request) => match handle_chemical_inventory(
                chem_inventory_request,
                requested_user,
                database_connection,
            ) {
                Ok(chem_inventory_response) => {
                    chem_inventory_response.to_rouille()
                }
                Err(err) => rouille::Response::from(err),
            },
        }
    } else if let Some(chemical_request_url) =
        request.remove_prefix("/chemicals")
    {
        match ChemicalRequest::from_rouille(&chemical_request_url) {
            Err(err) => rouille::Response::from(err),
            Ok(chemical_request) => {
                match handle_chemical(
                    chemical_request,
                    requested_user,
                    database_connection,
                ) {
                    Ok(chemical_response) => chemical_response.to_rouille(),
                    Err(err) => rouille::Response::from(err),
                }
            }
        }
    } else if let Some(question_request_url) =
        request.remove_prefix("/questions")
    {
        match QuestionRequest::from_rouille(&question_request_url) {
            Err(err) => rouille::Response::from(err),
            Ok(question_request) => {
                match handle_question(
                    question_request,
                    requested_user,
                    database_connection,
                ) {
                    Ok(question_response) => question_response.to_rouille(),
                    Err(err) => rouille::Response::from(err),
                }
            }
        }
    } else if let Some(question_category_request_url) =
        request.remove_prefix("/question_categories")
    {
        match QuestionCategoryRequest::from_rouille(
            &question_category_request_url,
        ) {
            Err(err) => rouille::Response::from(err),
            Ok(question_category_request) => {
                match handle_question_category(
                    question_category_request,
                    requested_user,
                    database_connection,
                ) {
                    Ok(question_category_response) => {
                        question_category_response.to_rouille()
                    }
                    Err(err) => rouille::Response::from(err),
                }
            }
        }
    } else if let Some(test_request_url) = request.remove_prefix("/tests") {
        match TestRequest::from_rouille(&test_request_url) {
            Err(err) => rouille::Response::from(err),
            Ok(test_request) => {
                match handle_test(
                    test_request,
                    requested_user,
                    database_connection,
                ) {
                    Ok(test_response) => test_response.to_rouille(),
                    Err(err) => rouille::Response::from(err),
                }
            }
        }
    } else if let Some(test_session_request_url) =
        request.remove_prefix("/test_sessions")
    {
        match TestSessionRequest::from_rouille(&test_session_request_url) {
            Err(err) => rouille::Response::from(err),
            Ok(test_session_request) => {
                match handle_test_session(
                    test_session_request,
                    requested_user,
                    database_connection,
                ) {
                    Ok(test_session_response) => {
                        test_session_response.to_rouille()
                    }
                    Err(err) => rouille::Response::from(err),
                }
            }
        }
    } else {
        rouille::Response::empty_404()
    }
}
