use diesel::Queryable;

use rouille::router;

use serde::Deserialize;
use serde::Serialize;

use url::form_urlencoded;

use log::warn;

use crate::errors::{Error, ErrorKind};

use crate::search::{NullableSearch, Search};

use super::schema::{access, user_access};

#[derive(Queryable, Serialize, Deserialize, Clone, Debug)]
pub struct Access {
    pub id: u64,
    pub access_name: String,
}

#[derive(Insertable, Serialize, Deserialize, Debug)]
#[table_name = "access"]
pub struct NewAccess {
    pub access_name: String,
}

#[derive(AsChangeset, Serialize, Deserialize, Debug)]
#[table_name = "access"]
pub struct PartialAccess {
    pub access_name: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct AccessList {
    pub accesses: Vec<Access>,
}

pub enum AccessRequest {
    GetAccess(u64),                   //id of access name searched
    CreateAccess(NewAccess), //new access type of some name to be created
    UpdateAccess(u64, PartialAccess), //Contains id to be changed to new access_name
    DeleteAccess(u64),                //if of access to be deleted
    FirstAccess(String),
}

impl AccessRequest {
    pub fn from_rouille(
        request: &rouille::Request,
    ) -> Result<AccessRequest, Error> {
        router!(request,
            (GET) (/{id: u64}) => {
                Ok(AccessRequest::GetAccess(id))
            },

            (POST) (/) => {
                let request_body = request.data().ok_or(Error::new(ErrorKind::Body))?;
                let new_access: NewAccess = serde_json::from_reader(request_body)?;

                Ok(AccessRequest::CreateAccess(new_access))
            },

            (POST) (/{id: u64}) => {
                let request_body = request.data().ok_or(Error::new(ErrorKind::Body))?;
                let update_access: PartialAccess = serde_json::from_reader(request_body)?;

                Ok(AccessRequest::UpdateAccess(id, update_access))
            },

            (DELETE) (/{id: u64}) => {
                Ok(AccessRequest::DeleteAccess(id))
            },

            (GET) (/first) => {
                if let Some(id_token) = request.header("id_token") {
                    Ok(AccessRequest::FirstAccess(id_token.to_string()))
                } else {
                    Err(Error::new(ErrorKind::AccessDenied))
                }
            },

            _ => {
                warn!("Could not create an access request for the given rouille request");
                Err(Error::new(ErrorKind::NotFound))
            }
        ) //end router
    }
}

pub enum AccessResponse {
    OneAccess(Access),
    NoResponse,
}

impl AccessResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            AccessResponse::OneAccess(access) => {
                rouille::Response::json(&access)
            }
            AccessResponse::NoResponse => rouille::Response::empty_204(),
        }
    }
}

#[derive(Queryable, Serialize, Deserialize, Debug)]
pub struct UserAccess {
    pub permission_id: u64,
    pub access_id: u64,
    pub user_id: u64,
    pub permission_level: Option<String>,
}

#[derive(Insertable, Serialize, Deserialize, Debug)]
#[table_name = "user_access"]
pub struct NewUserAccess {
    pub access_id: u64,
    pub user_id: u64,
    pub permission_level: Option<String>,
}

#[derive(AsChangeset, Serialize, Deserialize, Debug)]
#[table_name = "user_access"]
pub struct PartialUserAccess {
    pub access_id: Option<u64>,
    pub user_id: Option<u64>,
    pub permission_level: Option<Option<String>>,
}

pub struct SearchUserAccess {
    pub access_id: Search<u64>,
    pub user_id: Search<u64>,
    pub permission_level: NullableSearch<String>,
}

pub enum UserAccessRequest {
    SearchAccess(SearchUserAccess), //list of users with access id or (?) name
    GetCurrentUserAccess,           // Get the access for the logged in user
    GetAccess(u64),                 //get individual access entry from its id
    CheckAccess(u64, String), //entry allowing user of user_id to perform action of action_id
    CreateAccess(NewUserAccess), //entry to add to database
    UpdateAccess(u64, PartialUserAccess), //entry to update with new information
    DeleteAccess(u64),        //entry to delete from database
}

impl UserAccessRequest {
    pub fn from_rouille(
        request: &rouille::Request,
    ) -> Result<UserAccessRequest, Error> {
        let url_queries =
            form_urlencoded::parse(request.raw_query_string().as_bytes());

        router!(request,
            (GET) (/) => {

                let mut access_id_search = Search::NoSearch;
                let mut user_id_search = Search::NoSearch;
                let mut permission_level_search = NullableSearch::NoSearch;

                for (field, query) in url_queries {
                    match field.as_ref() as &str {
                        "access_id" => access_id_search =
                            Search::from_query(query.as_ref())?,
                        "user_id" => user_id_search =
                            Search::from_query(query.as_ref())?,
                        "permission_level" => permission_level_search =
                            NullableSearch::from_query(query.as_ref())?,
                        _ => return Err(Error::new(ErrorKind::Url)),
                    }
                }

                Ok(UserAccessRequest::SearchAccess(SearchUserAccess {
                    access_id: access_id_search,
                    user_id: user_id_search,
                    permission_level: permission_level_search,
                }))
            },

            (GET) (/current) => {
                Ok(UserAccessRequest::GetCurrentUserAccess)
            },

            (GET) (/{permission_id: u64}) => {
                Ok(UserAccessRequest::GetAccess(permission_id))
            },

            (GET) (/{user_id:u64}/{access_name: String}) => {
                Ok(UserAccessRequest::CheckAccess(user_id, access_name))
            },

            (POST) (/) => {
                let request_body = request.data()
                    .ok_or(Error::new(ErrorKind::Body))?;
                let new_user_access: NewUserAccess =
                    serde_json::from_reader(request_body)?;
                Ok(UserAccessRequest::CreateAccess(new_user_access))
            },

            (PUT) (/{id: u64}) => {
                let request_body = request.data()
                    .ok_or(Error::new(ErrorKind::Body))?;
                let update_user_access: PartialUserAccess =
                    serde_json::from_reader(request_body)?;
                Ok(UserAccessRequest::UpdateAccess(id, update_user_access))
            },

            (DELETE) (/{id: u64}) => {
                Ok(UserAccessRequest::DeleteAccess(id))
            },

            _ => {
                warn!("Could not create a user access request for the given rouille request");
                Err(Error::new(ErrorKind::NotFound))
            }
        ) //end router
    }
}

pub enum UserAccessResponse {
    AccessState(bool),
    ManyUserAccess(JoinedUserAccessList),
    ManyAccess(AccessList),
    OneUserAccess(UserAccess),
    NoResponse,
}

impl UserAccessResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            UserAccessResponse::AccessState(state) => {
                rouille::Response::text(if state { "true" } else { "false" })
            }
            UserAccessResponse::ManyUserAccess(user_accesses) => {
                rouille::Response::json(&user_accesses)
            }
            UserAccessResponse::ManyAccess(accesses) => {
                rouille::Response::json(&accesses)
            }
            UserAccessResponse::OneUserAccess(user_access) => {
                rouille::Response::json(&user_access)
            }
            UserAccessResponse::NoResponse => rouille::Response::empty_204(),
        }
    }
}

#[derive(Queryable, Serialize, Deserialize)]
pub struct JoinedUserAccess {
    pub permission_id: u64,
    pub user_id: u64,
    pub access_id: u64,
    pub first_name: String,
    pub last_name: String,
    pub banner_id: u32,
}

#[derive(Serialize, Deserialize)]
pub struct JoinedUserAccessList {
    pub entries: Vec<JoinedUserAccess>,
}
