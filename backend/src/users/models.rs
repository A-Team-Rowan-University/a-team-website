use diesel::Queryable;
use rouille::router;
use rouille::Request;
use serde::Deserialize;
use serde::Serialize;
use url::form_urlencoded;

use log::trace;
use log::warn;

use super::schema::users;

use crate::errors::WebdevError;
use crate::errors::WebdevErrorKind;

use crate::users::requests;

#[derive(Queryable, Serialize, Deserialize)]
pub struct User {
    pub id: u64,
    pub first_name: String,
    pub last_name: String,
    pub banner_id: u32,
    pub email: Option<String>,
}

#[derive(Insertable, Serialize, Deserialize)]
#[table_name = "users"]
pub struct NewUser {
    pub first_name: String,
    pub last_name: String,
    pub banner_id: u32,
    pub email: Option<String>,
}

#[derive(AsChangeset, Serialize, Deserialize)]
#[table_name = "users"]
pub struct PartialUser {
    pub first_name: Option<String>,
    pub last_name: Option<String>,
    pub banner_id: Option<u32>,
    pub email: Option<Option<String>>,
}

#[derive(Serialize, Deserialize)]
pub struct UserList {
    pub users: Vec<User>,
}

pub enum UserRequest {
    SearchUsers(PartialUser),
    GetUser(u64),
    CreateUser(NewUser),
    UpdateUser(u64, PartialUser),
    DeleteUser(u64),
}

impl UserRequest {
    pub fn from_rouille(request: &rouille::Request) -> Result<UserRequest, WebdevError> {
        trace!("Creating UserRequest from {:#?}", request);

        let url_query = form_urlencoded::parse(request.raw_query_string().as_bytes());

        router!(request,
            (GET) (/) => {

                let first_name_filter = url_query.clone().find_map(|(k, v)| {
                    if k == "first_name" {
                        Some(v.to_string())
                    } else {
                        None
                    }
                });

                let last_name_filter = url_query.clone().find_map(|(k, v)| {
                    if k == "last_name" {
                        Some(v.to_string())
                    } else {
                        None
                    }
                });

                let banner_id_filter = url_query.clone().find_map(|(k, v)| {
                    if k == "banner_id" {
                        Some(v.parse())
                    } else {
                        None
                    }
                });

                // Propogate the error if the id could not be parsed as a u32
                let banner_id_filter = match banner_id_filter {
                    Some(result) => Some(result?),
                    None => None,
                };

                // TODO This email filter only covers 2 of the possibilities:
                //
                // No email filter:     Yes
                // None email:          No
                // Some email:          No
                // Some specific email: Yes
                //
                // Should expect a query like
                // No email:            email=None
                // Some email:          email=Some
                // Some specific email: email=Some,hollabaut1@students.rowan.edu
                let email_filter = url_query.clone().find_map(|(k, v)| {
                    if k == "email" {
                        Some(Some(v.to_string()))
                    } else {
                        None
                    }
                });

                Ok(UserRequest::SearchUsers(PartialUser {
                    first_name: first_name_filter,
                    last_name: last_name_filter,
                    banner_id: banner_id_filter,
                    email: email_filter,
                }))
            },

            (GET) (/{id: u64}) => {
                Ok(UserRequest::GetUser(id))
            },

            (POST) (/) => {
                let request_body = request.data().ok_or(WebdevError::new(WebdevErrorKind::Format))?;
                let new_user: NewUser = serde_json::from_reader(request_body)?;

                Ok(UserRequest::CreateUser(new_user))
            },

            (POST) (/{id: u64}) => {
                let request_body = request.data().ok_or(WebdevError::new(WebdevErrorKind::Format))?;
                let update_user: PartialUser = serde_json::from_reader(request_body)?;

                Ok(UserRequest::UpdateUser(id, update_user))
            },

            (DELETE) (/{id: u64}) => {
                Ok(UserRequest::DeleteUser(id))
            },

            _ => {
                warn!("Could not create a user request for the given rouille request");
                Err(WebdevError::new(WebdevErrorKind::NotFound))
            }
        )
    }
}

pub enum UserResponse {
    OneUser(User),
    ManyUsers(UserList),
    NoResponse,
}

impl UserResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            UserResponse::OneUser(user) => rouille::Response::json(&user),
            UserResponse::ManyUsers(users) => rouille::Response::json(&users),
            UserResponse::NoResponse => rouille::Response::empty_204(),
        }
    }
}
