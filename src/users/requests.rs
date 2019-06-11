use crate::diesel::NullableExpressionMethods;
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

use crate::search::Search;

use crate::access::requests::check_to_run;

use crate::access::models::NewUserAccess;

use crate::users::models::{
    JoinedUser, NewRawUser, NewUser, PartialUser, RawUser, SearchUser, User,
    UserList, UserRequest, UserResponse,
};

use crate::access::schema::access as access_schema;
use crate::access::schema::user_access as user_access_schema;
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

fn condense_join(joined: Vec<JoinedUser>) -> Vec<User> {
    let mut condensed: Vec<User> = Vec::new();

    for join in joined {
        let mut access = if let Some(access) = &join.access {
            vec![access.clone()]
        } else {
            Vec::new()
        };

        if let Some(user) = condensed.iter_mut().find(|u| u.id == join.user.id)
        {
            user.accesses.append(&mut access);
        } else {
            let user = User {
                id: join.user.id,
                first_name: join.user.first_name,
                last_name: join.user.last_name,
                banner_id: join.user.banner_id,
                email: join.user.email,
                accesses: access,
            };

            condensed.push(user);
        }
    }
    condensed
}

pub(crate) fn search_users(
    user: SearchUser,
    database_connection: &MysqlConnection,
) -> Result<UserList, Error> {
    let mut users_query = users_schema::table
        .left_join(user_access_schema::table.left_join(access_schema::table))
        .select((
            (
                users_schema::id,
                users_schema::first_name,
                users_schema::last_name,
                users_schema::banner_id,
                users_schema::email,
            ),
            (access_schema::id, access_schema::access_name).nullable(),
        ))
        .into_boxed();

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

    let joined_users = users_query.load::<JoinedUser>(database_connection)?;

    let mut users = condense_join(joined_users);

    let user_list = UserList { users};

    Ok(user_list)
}

pub(crate) fn get_user(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<User, Error> {
    let joined_users = users_schema::table
        .left_join(user_access_schema::table.left_join(access_schema::table))
        .select((
            (
                users_schema::id,
                users_schema::first_name,
                users_schema::last_name,
                users_schema::banner_id,
                users_schema::email,
            ),
            (access_schema::id, access_schema::access_name).nullable(),
        ))
        .filter(users_schema::id.eq(id))
        .load::<JoinedUser>(database_connection)?;

    let mut users = condense_join(joined_users);

    match users.pop() {
        Some(user) => Ok(user),
        None => Err(Error::new(ErrorKind::NotFound)),
    }
}

pub(crate) fn create_user(
    user: NewUser,
    database_connection: &MysqlConnection,
) -> Result<User, Error> {

    let new_raw_user = NewRawUser {
        first_name: user.first_name,
        last_name: user.last_name,
        banner_id: user.banner_id,
        email: user.email,
    };

    diesel::insert_into(users_schema::table)
        .values(new_raw_user)
        .execute(database_connection)?;

    let mut inserted_users = users_schema::table
        .filter(diesel::dsl::sql("id = LAST_INSERT_ID()"))
        .load::<RawUser>(database_connection)?;

    if let Some(inserted_user) = inserted_users.pop() {
        let new_user_accesses: Vec<_> = user.accesses.into_iter().map(|access_id| NewUserAccess {
            access_id: access_id,
            user_id: inserted_user.id,
            permission_level: None,
        }).collect();

        diesel::insert_into(user_access_schema::table)
            .values(new_user_accesses)
            .execute(database_connection)?;

        let inserted_user = get_user(inserted_user.id, database_connection)?;

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
