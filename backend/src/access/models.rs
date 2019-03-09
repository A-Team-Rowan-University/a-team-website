use diesel::Queryable;
use serde::Deserialize;
use serde::Serialize;

use super::schema::{access, user_access};

use crate::errors::{WebdevError, WebdevErrorKind};

use crate::users::models::{User, UserList};

#[derive(Queryable, Serialize, Deserialize)]
pub struct Access {
    pub id: u64,
    pub access_name: String,
}

#[derive(Insertable, Serialize, Deserialize)]
#[table_name = "access"]
pub struct NewAccess {
    pub access_name: String,
}

pub enum AccessRequest {
    CreateAccess(NewAccess), //new access type of some name to be created
    GetAccess(u64), //id of access name searched
    DeleteAccess(u64), //if of access to be deleted
    RenameAccess(Access), //Contains id to be changed to new access_name
}

impl AccessRequest {
    fn from_rouille(request: &rouille::Request) -> Result<AccessRequest, WebdevError> {

    }
}



#[derive(Queryable, Serialize, Deserialize)]
pub struct UserAccess {
    pub permission_id: u64,
    pub access_id: u64,
    pub user_id: u64,
    pub permission_level: Option<String>,
}

#[derive(Insertable, Serialize, Deserialize)]
#[table_name = "user_access"]
pub struct NewUserAccess {
    pub access_id: u64,
    pub user_id: u64,
    pub permission_level: Option<String>,
}

#[derive(AsChangeset, Serialize, Deserialize)]
#[table_name = "user_access"]
pub struct PartialUserAccess {
    pub access_id: u64,
    pub user_id: u64,
    pub permission_level: Option<Option<String>>,
}

pub enum UserAccessRequest {
    SearchAccess(UserList), //list of users with access id or (?) name
    HasAccess(UserAccess), //entry allowing user of user_id to perform action of action_id
    CreateAccess(NewUserAccess), //entry to add to database
    UpdateAccess(u64, PartialUserAccess), //entry to update with new information
    DeleteUserAccess(u64), //entry to delete from database
}

impl UserAccessRequest {
    fn from_rouille(request: &rouille::Request) -> Result<UserAccessRequest, WebdevError> {

    }
}
