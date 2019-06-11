use csv;
use diesel::prelude::*;
use diesel::MysqlConnection;
use dotenv::dotenv;
use log::debug;
use log::error;
use log::info;
use serde::Deserialize;
use serde::Serialize;
use webdev_lib::users::models::{NewUser, UserRequest};
use webdev_lib::users::requests;

#[derive(Serialize, Deserialize, Debug)]
//Struct to take the data from the csv
struct CsvUser {
    #[serde(rename = "Banner ID")]
    banner_id: i32,
    #[serde(rename = "Last Name")]
    last_name: String,
    #[serde(rename = "First Name")]
    first_name: String,
    #[serde(rename = "Email")]
    email: String,
    #[serde(rename = "Year")]
    year: String,
    #[serde(rename = "Department")]
    department: String,
}
fn main() {
    //Diesel things
    dotenv().ok();

    simplelog::TermLogger::init(
        simplelog::LevelFilter::Trace,
        simplelog::Config::default(),
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

    let connection = match MysqlConnection::establish(&database_url) {
        Ok(c) => c,
        Err(e) => {
            error!("Could not connect to database: {}", e);
            return;
        }
    };

    debug!("Connected to database");
    //Get file name and path from args
    use std::env;
    let arg = env::args().next();
    let filename = match arg {
        Some(name) => name,
        None => {
            error!("Needs a filename");
            return;
        }
    };
    debug!("{}", filename);
    //Import the csv into an iterator
    let mut user_count = 0;
    let all_users_result = csv::Reader::from_path(filename);
    let mut all_users = match all_users_result {
        Ok(data) => data,
        Err(e) => {
            error!("Bad file. Error {}", e);
            return;
        }
    };
    //Go through each item in the iterator
    for result in all_users.deserialize() {
        //Check to see if it's valid
        let csv_user: CsvUser = match result {
            Ok(data) => data,
            Err(e) => {
                error!("Bad data, {:?}", e);
                return;
            }
        };
        //Convert the user data from the csv and create a New User from it
        let new_user: NewUser = NewUser {
            first_name: csv_user.first_name,
            last_name: csv_user.last_name,
            email: csv_user.email,
            banner_id: csv_user.banner_id as u32,
            accesses: Vec::new(),
        };
        //Import new user into database
        let import_user = UserRequest::CreateUser(new_user);
        requests::handle_user(import_user, Some(0), &connection).unwrap();
        user_count = user_count + 1;
    }
    info!("Imported {} user(s)", user_count);
}
