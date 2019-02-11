use log::debug;
use log::error;
use log::info;
use log::trace;
use log::warn;
use diesel::prelude::*;
use diesel::MysqlConnection;
use dotenv::dotenv;
use csv;
use web_dev::users::models::{NewUser,UserRequest};
use web_dev::users::requests;
use serde::Deserialize;
use serde::Serialize;

#[derive(Serialize, Deserialize, Debug)]
struct Csv_User {
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

fn main(){
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

	use std::env;
	let arg = env::args().nth(1);
	let filename = 	match arg {
		Some(name) => name,
		None => {
			println!("Needs a filename");
			return;
		}
	};
	println!("{}", filename);
	
	let all_users_result = csv::Reader::from_path(filename);
	let mut all_users = match all_users_result{
		Ok(data) => data,
		Err(e) => {
				println!("Bad file. Error {}",e);
				return;
			}
	};		
	for result in all_users.deserialize(){
		let csv_user: Csv_User = match result{
			Ok(data) => data,
			Err(e) => {
				println!("Bad data, {:?}", e);
				return;
			}
		};
		let new_user:NewUser = NewUser{
			first_name: csv_user.first_name,
			last_name: csv_user.last_name,
			email:  Some(csv_user.email),
			banner_id: csv_user.banner_id as u32,
		};
		
		requests::create_user(new_user, &connection);
	}
}

