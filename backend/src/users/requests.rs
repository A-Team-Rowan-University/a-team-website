use diesel;
use diesel::mysql::Mysql;
use diesel::mysql::MysqlConnection;
use diesel::query_builder::AsQuery;
use diesel::query_builder::BoxedSelectStatement;
use diesel::ExpressionMethods;
use diesel::QueryDsl;
use diesel::RunQueryDsl;

use log::trace;

use crate::users::models::{NewUser, PartialUser, User, UserList, UserRequest, UserResponse};
use crate::users::schema::users as users_schema;

use crate::errors::WebdevError;
use crate::errors::WebdevErrorKind;

pub fn handle_user(
    request: UserRequest,
    database_connection: &MysqlConnection,
) -> Result<UserResponse, WebdevError> {
    match request {
        UserRequest::SearchUsers(user) => {
            search_users(user, database_connection).map(|u| UserResponse::ManyUsers(u))
        }
        UserRequest::GetUser(id) => {
            get_user(id, database_connection).map(|u| UserResponse::OneUser(u))
        }
        UserRequest::CreateUser(user) => {
            create_user(user, database_connection).map(|u| UserResponse::OneUser(u))
        }
        UserRequest::UpdateUser(id, user) => {
            update_user(id, user, database_connection).map(|_| UserResponse::NoResponse)
        }
        UserRequest::DeleteUser(id) => {
            delete_user(id, database_connection).map(|_| UserResponse::NoResponse)
        }
    }
}

fn search_users(
    partial_user: PartialUser,
    database_connection: &MysqlConnection,
) -> Result<UserList, WebdevError> {
    let mut users_query = users_schema::table.as_query().into_boxed();

    if let Some(first_name) = partial_user.first_name {
        users_query = users_query.filter(users_schema::first_name.eq(first_name));
    }

    if let Some(last_name) = partial_user.last_name {
        users_query = users_query.filter(users_schema::last_name.eq(last_name));
    }

    if let Some(banner_id) = partial_user.banner_id {
        users_query = users_query.filter(users_schema::banner_id.eq(banner_id));
    }

    if let Some(option_email) = partial_user.email {
        if let Some(email) = option_email {
            users_query = users_query.filter(users_schema::email.eq(email));
        } else {
            users_query = users_query.filter(users_schema::email.is_null());
        }
    }

    let found_users = users_query.load::<User>(database_connection)?;
    let user_list = UserList { users: found_users };

    Ok(user_list)
}

fn get_user(id: u64, database_connection: &MysqlConnection) -> Result<User, WebdevError> {
    let mut found_users = users_schema::table
        .filter(users_schema::id.eq(id))
        .load::<User>(database_connection)?;

    match found_users.pop() {
        Some(user) => Ok(user),
        None => Err(WebdevError::new(WebdevErrorKind::NotFound))
    }
}

fn create_user(user: NewUser, database_connection: &MysqlConnection) -> Result<User, WebdevError> {
    diesel::insert_into(users_schema::table)
        .values(user)
        .execute(database_connection)?;

    let mut inserted_users = users_schema::table
        .filter(diesel::dsl::sql("id = LAST_INSERT_ID()"))
        .load::<User>(database_connection)?;

    if let Some(inserted_user) = inserted_users.pop() {
        Ok(inserted_user)
    } else {
        Err(WebdevError::new(WebdevErrorKind::Database))
    }
}

fn update_user(
    id: u64,
    user: PartialUser,
    database_connection: &MysqlConnection,
) -> Result<(), WebdevError> {
    diesel::update(users_schema::table)
        .filter(users_schema::id.eq(id))
        .set(&user)
        .execute(database_connection)?;
    Ok(())
}

fn delete_user(id: u64, database_connection: &MysqlConnection) -> Result<(), WebdevError> {
    diesel::delete(users_schema::table.filter(users_schema::id.eq(id)))
        .execute(database_connection)?;

    Ok(())
}
