use diesel::Queryable;

use rouille::router;

use serde::Deserialize;
use serde::Serialize;

use url::form_urlencoded;

use log::warn;

use crate::errors::{Error, ErrorKind};

use crate::search::Search;

use super::schema::{permissions, user_permissions};

#[derive(Queryable, Serialize, Deserialize, Clone, Debug)]
pub struct Permission {
    pub id: u64,
    pub permission_name: String,
}

#[derive(Insertable, Serialize, Deserialize, Debug)]
#[table_name = "permissions"]
pub struct NewPermission {
    pub permission_name: String,
}

#[derive(AsChangeset, Serialize, Deserialize, Debug)]
#[table_name = "permissions"]
pub struct PartialPermission {
    pub permission_name: Option<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct PermissionList {
    pub permissions: Vec<Permission>,
}

pub enum PermissionRequest {
    GetPermission(u64), //id of permission name searched permission
    CreatePermission(NewPermission), //new permission type of some name to be created
    UpdatePermission(u64, PartialPermission), //Contains id to be changed to new permission_name
    DeletePermission(u64),                    //if of permission to be deleted
    FirstPermission(String),
    GetPermissions // get all possible permissions from sql table
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
                    Err(Error::new(ErrorKind::PermissionDenied))
                }
            },

            (GET) (/) => {
                Ok(PermissionRequest::GetAllPossiblePermissions)
            }
            ,

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
    ManyPermissions(PermissionList)
}

impl PermissionResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            PermissionResponse::OnePermission(permission) => {
                rouille::Response::json(&permission)
            }
            PermissionResponse::ManyPermissions(permissions) => {
                rouille::Response::json(&permissions)
            }

            PermissionResponse::NoResponse => rouille::Response::empty_204(),

        }
    }
}

#[derive(Queryable, Serialize, Deserialize, Debug)]
pub struct UserPermission {
    pub user_permission_id: u64,
    pub permission_id: u64,
    pub user_id: u64,
}

#[derive(Insertable, Serialize, Deserialize, Debug)]
#[table_name = "user_permissions"]
pub struct NewUserPermission {
    pub permission_id: u64,
    pub user_id: u64,
}

#[derive(AsChangeset, Serialize, Deserialize, Debug)]
#[table_name = "user_permissions"]
pub struct PartialUserPermission {
    pub permission_id: Option<u64>,
    pub user_id: Option<u64>,
}

pub struct SearchUserPermission {
    pub permission_id: Search<u64>,
    pub user_id: Search<u64>,
}

pub enum UserPermissionRequest {
    SearchPermission(SearchUserPermission), //list of users with permission id or (?) name
    GetCurrentUserPermission, // Get the permission for the logged in user
    GetPermission(u64),       //get individual permission entry from its id
    CheckPermission(u64, String), //entry allowing user of user_id to perform action of action_id
    CreatePermission(NewUserPermission), //entry to add to database
    UpdatePermission(u64, PartialUserPermission), //entry to update with new information
    DeletePermission(u64), //entry to delete from database
}

impl UserPermissionRequest {
    pub fn from_rouille(
        request: &rouille::Request,
    ) -> Result<UserPermissionRequest, Error> {
        let url_queries =
            form_urlencoded::parse(request.raw_query_string().as_bytes());

        router!(request,
            (GET) (/) => {

                let mut permission_id_search = Search::NoSearch;
                let mut user_id_search = Search::NoSearch;

                for (field, query) in url_queries {
                    match field.as_ref() as &str {
                        "permission_id" => permission_id_search =
                            Search::from_query(query.as_ref())?,
                        "user_id" => user_id_search =
                            Search::from_query(query.as_ref())?,
                        _ => return Err(Error::new(ErrorKind::Url)),
                    }
                }

                Ok(UserPermissionRequest::SearchPermission(SearchUserPermission {
                    permission_id: permission_id_search,
                    user_id: user_id_search,
                }))
            },

            (GET) (/current) => {
                Ok(UserPermissionRequest::GetCurrentUserPermission)
            },

            (GET) (/{permission_id: u64}) => {
                Ok(UserPermissionRequest::GetPermission(permission_id))
            },

            (GET) (/{user_id:u64}/{permission_name: String}) => {
                Ok(UserPermissionRequest::CheckPermission(user_id, permission_name))
            },

            (POST) (/) => {
                let request_body = request.data()
                    .ok_or(Error::new(ErrorKind::Body))?;
                let new_user_permission: NewUserPermission =
                    serde_json::from_reader(request_body)?;
                Ok(UserPermissionRequest::CreatePermission(new_user_permission))
            },

            (PUT) (/{id: u64}) => {
                let request_body = request.data()
                    .ok_or(Error::new(ErrorKind::Body))?;
                let update_user_permission: PartialUserPermission =
                    serde_json::from_reader(request_body)?;
                Ok(UserPermissionRequest::UpdatePermission(id, update_user_permission))
            },

            (DELETE) (/{id: u64}) => {
                Ok(UserPermissionRequest::DeletePermission(id))
            },

            _ => {
                warn!("Could not create a user permission request for the given rouille request");
                Err(Error::new(ErrorKind::NotFound))
            }
        ) //end router
    }
}

pub enum UserPermissionResponse {
    PermissionState(bool),
    ManyUserPermission(JoinedUserPermissionList),
    ManyPermission(PermissionList),
    OneUserPermission(UserPermission),
    NoResponse,
}

impl UserPermissionResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            UserPermissionResponse::PermissionState(state) => {
                rouille::Response::text(if state { "true" } else { "false" })
            }
            UserPermissionResponse::ManyUserPermission(user_permissions) => {
                rouille::Response::json(&user_permissions)
            }
            UserPermissionResponse::ManyPermission(permissions) => {
                rouille::Response::json(&permissions)
            }
            UserPermissionResponse::OneUserPermission(user_permission) => {
                rouille::Response::json(&user_permission)
            }
            UserPermissionResponse::NoResponse => {
                rouille::Response::empty_204()
            }
        }
    }
}

#[derive(Queryable, Serialize, Deserialize)]
pub struct JoinedUserPermission {
    pub user_permission_id: u64,
    pub user_id: u64,
    pub permission_id: u64,
    pub first_name: String,
    pub last_name: String,
    pub banner_id: u32,
}

#[derive(Serialize, Deserialize)]
pub struct JoinedUserPermissionList {
    pub entries: Vec<JoinedUserPermission>,
}
