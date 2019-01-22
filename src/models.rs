use diesel::Queryable;
use serde::Deserialize;
use serde::Serialize;

use super::schema::users;

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
