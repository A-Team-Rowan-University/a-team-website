use diesel::Queryable;
use rouille::router;
use rouille::Request;
use serde::Deserialize;
use serde::Serialize;

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
        router!(request,
            (GET) (/) => {

                // TODO Searching really needs to be fixed up

                let first_name_filter = request.get_param("first_name_exact");
                let last_name_filter = request.get_param("last_name_exact");
                let banner_id_filter =
                    if let Some(p) = request.get_param("banner_id_exact") {
                        Some(p.parse()?)
                    } else {
                        None
                    };

                let has_email_filter =
                    if let Some(p) = request.get_param("has_email") {
                        Some(p.parse()?)
                    } else {
                        None
                    };

                let email_filter = request.get_param("email");

                /*
                 * has_email | email | out
                 *   None      None    None
                 *  Some(t)    None    None ?
                 *  Some(f)    None    Some(None)
                 *   None     Some(s)  Some(Some(s))
                 *  Some(t)   Some(s)  Some(Some(s))
                 *  Some(f)   Some(s)  Some(None)
                 */

                let email = match (has_email_filter, email_filter) {
                    (None, None) => None,
                    (Some(true), None) => None,
                    (Some(false), None) => Some(None),
                    (None, Some(s)) => Some(Some(s)),
                    (Some(true), Some(s)) => Some(Some(s)),
                    (Some(false), Some(s)) => Some(None),
                };

                Ok(UserRequest::SearchUsers(PartialUser {
                    first_name: first_name_filter,
                    last_name: last_name_filter,
                    banner_id: banner_id_filter,
                    email: email,
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
