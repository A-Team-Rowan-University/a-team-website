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

use crate::search::NullableSearch;
use crate::search::Search;

use crate::users::requests;

#[derive(Queryable, Serialize, Deserialize)]
pub struct User {
    pub id: i64,
    pub first_name: String,
    pub last_name: String,
    pub banner_id: u32,
    pub email: Option<String>,
}

#[derive(Insertable, Serialize, Deserialize, Debug)]
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

pub struct SearchUser {
    pub first_name: Search<String>,
    pub last_name: Search<String>,
    pub banner_id: Search<u32>,
    pub email: NullableSearch<String>,
}

#[derive(Serialize, Deserialize)]
pub struct UserList {
    pub users: Vec<User>,
}

pub enum UserRequest {
    SearchUsers(SearchUser),
    GetUser(i64),
    CreateUser(NewUser),
    UpdateUser(i64, PartialUser),
    DeleteUser(i64),
}

impl UserRequest {
    pub fn from_rouille(request: &rouille::Request) -> Result<UserRequest, WebdevError> {
        trace!("Creating UserRequest from {:#?}", request);

        let url_queries = form_urlencoded::parse(request.raw_query_string().as_bytes());

        router!(request,
            (GET) (/) => {

                let mut first_name_search = Search::NoSearch;
                let mut last_name_search = Search::NoSearch;
                let mut banner_id_search = Search::NoSearch;
                let mut email_search = NullableSearch::NoSearch;

                for (field, query) in url_queries {
                    match field.as_ref() {
                        "first_name" => first_name_search = Search::from_query(query.as_ref())?,
                        "last_name" => last_name_search = Search::from_query(query.as_ref())?,
                        "banner_id" => banner_id_search = Search::from_query(query.as_ref())?,
                        "email" => email_search = NullableSearch::from_query(query.as_ref())?,
                        _ => return Err(WebdevError::new(WebdevErrorKind::Format)),
                    }
                }

                Ok(UserRequest::SearchUsers(SearchUser {
                    first_name: first_name_search,
                    last_name: last_name_search,
                    banner_id: banner_id_search,
                    email: email_search,
                }))
            },

            (GET) (/{id: i64}) => {
                Ok(UserRequest::GetUser(id))
            },

            (POST) (/) => {
                let request_body = request.data().ok_or(WebdevError::new(WebdevErrorKind::Format))?;
                let new_user: NewUser = serde_json::from_reader(request_body)?;

                Ok(UserRequest::CreateUser(new_user))
            },

            (POST) (/{id: i64}) => {
                let request_body = request.data().ok_or(WebdevError::new(WebdevErrorKind::Format))?;
                let update_user: PartialUser = serde_json::from_reader(request_body)?;

                Ok(UserRequest::UpdateUser(id, update_user))
            },

            (DELETE) (/{id: i64}) => {
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
