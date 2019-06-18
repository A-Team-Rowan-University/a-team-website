use diesel::Queryable;

use rouille::router;

use serde::Deserialize;
use serde::Serialize;

use url::form_urlencoded;

use log::warn;

use crate::errors::{Error, ErrorKind};

use crate::search::{NullableSearch, Search};

use super::schema::{permission, user_access};

#[derive(Queryable, Serialize, Deserialize, Clone, Debug)]
pub struct Permission {
    pub id: u64,
    pub permission_name: String,
}

#[derive(Insertable, Serialize, Deserialize, Debug)]
#[table_name = "permission"]
pub struct NewPermission {
    pub permission_name: String,
}

#[derive(AsChangeset, Serialize, Deserialize, Debug)]
#[table_name = "permission"]
pub struct PartialPermission {
    pub permission_name: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct PermissionList {
    pub permissions: Vec<Permission>,
}

pub enum PermissionRequest {
    GetPermission(u64),                   //id of access name searched
    CreatePermission(NewPermission), //new access type of some name to be created
    UpdatePermission(u64, PartialPermission), //Contains id to be changed to new access_name
    DeletePermission(u64),                //if of access to be deleted
    FirstPermission(String),
}

impl PermissionRequest {
    pub fn from_rouille(
        request: &rouille::Request,
    ) -> Result<PermissionRequest, Error> {
        router!(request,
            (GET) (/{id: u64}) => {
                Ok(PermissionRequest::GetPermission(id))
            },

            (POST) (/) => {
                let request_body = request.data().ok_or(Error::new(ErrorKind::Body))?;
                let new_permission: NewPermission = serde_json::from_reader(request_body)?;

                Ok(PermissionRequest::CreatePermission(new_permission))
            },

            (POST) (/{id: u64}) => {
                let request_body = request.data().ok_or(Error::new(ErrorKind::Body))?;
                let update_permission: PartialPermission = serde_json::from_reader(request_body)?;

                Ok(PermissionRequest::UpdatePermission(id, update_permission))
            },

            (DELETE) (/{id: u64}) => {
                Ok(PermissionRequest::DeletePermission(id))
            },

            (GET) (/first) => {
                if let Some(id_token) = request.header("id_token") {
                    Ok(PermissionRequest::FirstPermission(id_token.to_string()))
                } else {
                    Err(Error::new(ErrorKind::AccessDenied))
                }
            },

            _ => {
                warn!("Could not create an permission request for the given rouille request");
                Err(Error::new(ErrorKind::NotFound))
            }
        ) //end router
    }
}

pub enum PermissionResponse {
    OnePermission(Permission),
    NoResponse,
}

impl PermissionResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            PermissionResponse::OnePermission(permission) => {
                rouille::Response::json(&permission)
            }
            PermissionResponse::NoResponse => rouille::Response::empty_204(),
        }
    }
}

#[derive(Queryable, Serialize, Deserialize, Debug)]
pub struct UserAccess {
    pub access_id: u64,
    pub permission_id: u64,
    pub user_id: u64,
    pub access_level: Option<String>,
}

#[derive(Insertable, Serialize, Deserialize, Debug)]
#[table_name = "user_access"]
pub struct NewUserAccess {
    pub permission_id: u64,
    pub user_id: u64,
    pub access_level: Option<String>,
}

#[derive(AsChangeset, Serialize, Deserialize, Debug)]
#[table_name = "user_access"]
pub struct PartialUserAccess {
    pub permission_id: Option<u64>,
    pub user_id: Option<u64>,
    pub access_level: Option<Option<String>>,
}

pub struct SearchUserAccess {
    pub permission_id: Search<u64>,
    pub user_id: Search<u64>,
    pub access_level: NullableSearch<String>,
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
                    permission_id: access_id_search,
                    user_id: user_id_search,
                    access_level: permission_level_search,
                }))
            },

            (GET) (/current) => {
                Ok(UserAccessRequest::GetCurrentUserAccess)
            },

            (GET) (/{permission_id: u64}) => {
                Ok(UserAccessRequest::GetAccess(permission_id))
            },

            (GET) (/{user_id:u64}/{permission_name: String}) => {
                Ok(UserAccessRequest::CheckAccess(user_id, permission_name))
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
    ManyAccess(PermissionList),
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
