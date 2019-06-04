use diesel;
use diesel::mysql::MysqlConnection;
use diesel::query_builder::AsQuery;
use diesel::ExpressionMethods;
use diesel::QueryDsl;
use diesel::RunQueryDsl;
use diesel::TextExpressionMethods;

use log::trace;
use log::warn;

use crate::errors::Error;
use crate::errors::ErrorKind;

use crate::search::NullableSearch;
use crate::search::Search;

use crate::access::requests::check_to_run;

use crate::users::models::{
    NewUser, PartialUser, SearchUser, User, UserList, UserRequest, UserResponse,
};
use crate::users::schema::users as users_schema;

pub fn handle_user(
    request: UserRequest,
    requested_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<UserResponse, Error> {
    match request {
        UserRequest::SearchUsers(user) => {
            match check_to_run(requested_user, "GetUsers", database_connection)
            {
                Ok(()) => search_users(user, database_connection)
                    .map(|u| UserResponse::ManyUsers(u)),
                Err(e) => Err(e),
            }
        }
        UserRequest::GetUser(id) => {
            match check_to_run(requested_user, "GetUsers", database_connection)
            {
                Ok(()) => get_user(id, database_connection)
                    .map(|u| UserResponse::OneUser(u)),
                Err(e) => Err(e),
            }
        }
        UserRequest::CreateUser(user) => {
            match check_to_run(
                requested_user,
                "CreateUsers",
                database_connection,
            ) {
                Ok(()) => create_user(user, database_connection)
                    .map(|u| UserResponse::OneUser(u)),
                Err(e) => Err(e),
            }
        }
        UserRequest::UpdateUser(id, user) => {
            match check_to_run(
                requested_user,
                "DeleteUsers",
                database_connection,
            ) {
                Ok(()) => update_user(id, user, database_connection)
                    .map(|_| UserResponse::NoResponse),
                Err(e) => Err(e),
            }
        }
        UserRequest::DeleteUser(id) => {
            match check_to_run(requested_user, "GetUsers", database_connection)
            {
                Ok(()) => delete_user(id, database_connection)
                    .map(|_| UserResponse::NoResponse),
                Err(e) => Err(e),
            }
        }
    }
}

pub(crate) fn search_users(
    user: SearchUser,
    database_connection: &MysqlConnection,
) -> Result<UserList, Error> {
    let mut users_query = users_schema::table.as_query().into_boxed();

    match user.first_name {
        Search::Partial(s) => {
            users_query = users_query
                .filter(users_schema::first_name.like(format!("%{}%", s)))
        }

        Search::Exact(s) => {
            users_query = users_query.filter(users_schema::first_name.eq(s))
        }

        Search::NoSearch => {}
    }

    match user.last_name {
        Search::Partial(s) => {
            users_query = users_query
                .filter(users_schema::last_name.like(format!("%{}%", s)))
        }

        Search::Exact(s) => {
            users_query = users_query.filter(users_schema::last_name.eq(s))
        }

        Search::NoSearch => {}
    }

    match user.banner_id {
        Search::Partial(s) => {
            warn!("Trying to partial search by banner id. This is not currently supported, so performing exact search instead");
            trace!("Partial search required the field to be a text field, but banner id is currently an integet");;
            users_query = users_query.filter(users_schema::banner_id.eq(s))
        }

        Search::Exact(s) => {
            users_query = users_query.filter(users_schema::banner_id.eq(s))
        }

        Search::NoSearch => {}
    }

    match user.email {
        Search::Partial(s) => {
            users_query =
                users_query.filter(users_schema::email.like(format!("%{}%", s)))
        }

        Search::Exact(s) => {
            users_query = users_query.filter(users_schema::email.eq(s))
        }

        Search::NoSearch => {}
    }

    let found_users = users_query.load::<User>(database_connection)?;
    let user_list = UserList { users: found_users };

    Ok(user_list)
}

pub(crate) fn get_user(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<User, Error> {
    let mut found_users = users_schema::table
        .filter(users_schema::id.eq(id))
        .load::<User>(database_connection)?;

    match found_users.pop() {
        Some(user) => Ok(user),
        None => Err(Error::new(ErrorKind::NotFound)),
    }
}

pub(crate) fn create_user(
    user: NewUser,
    database_connection: &MysqlConnection,
) -> Result<User, Error> {
    diesel::insert_into(users_schema::table)
        .values(user)
        .execute(database_connection)?;

    let mut inserted_users = users_schema::table
        .filter(diesel::dsl::sql("id = LAST_INSERT_ID()"))
        .load::<User>(database_connection)?;

    if let Some(inserted_user) = inserted_users.pop() {
        Ok(inserted_user)
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

pub(crate) fn update_user(
    id: u64,
    user: PartialUser,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::update(users_schema::table)
        .filter(users_schema::id.eq(id))
        .set(&user)
        .execute(database_connection)?;
    Ok(())
}

pub(crate) fn delete_user(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::delete(users_schema::table.filter(users_schema::id.eq(id)))
        .execute(database_connection)?;

    Ok(())
}
