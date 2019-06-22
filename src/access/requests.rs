use diesel;
use diesel::mysql::types::Unsigned;
use diesel::mysql::Mysql;
use diesel::mysql::MysqlConnection;
use diesel::sql_types;
use diesel::ExpressionMethods;
use diesel::QueryDsl;
use diesel::RunQueryDsl;
use diesel::TextExpressionMethods;

use google_signin;

use log::debug;
use log::trace;
use log::warn;

use crate::errors::{Error, ErrorKind};

use crate::search::{NullableSearch, Search};

use super::models::{
    Permission, PermissionList, PermissionRequest, PermissionResponse, JoinedUserAccess,
    JoinedUserAccessList, NewPermission, NewUserAccess, PartialPermission,
    PartialUserAccess, SearchUserAccess, UserAccess, UserAccessRequest,
    UserAccessResponse,
};

use crate::users::models::{NewUser, SearchUser};
use crate::users::requests::create_user;
use crate::users::requests::search_users;

use super::schema::permission as permission_schema;
use super::schema::user_access as user_access_schema;
use crate::users::schema::users as users_schema;

pub fn validate_token(
    id_token: &str,
    database_connection: &MysqlConnection,
) -> Result<u64, Error> {
    let mut client = google_signin::Client::new();
    client.audiences.push(String::from(
        "918184954544-jm1aufr31fi6sdjs1140p7p3rouaka14.apps.googleusercontent.com",
    ));

    let id_info = client.verify(id_token)?;

    trace!("Validated token: {:?}", id_info);

    if let Some(email) = id_info.email {
        let mut found_users = search_users(
            SearchUser {
                first_name: Search::NoSearch,
                last_name: Search::NoSearch,
                banner_id: Search::NoSearch,
                email: Search::Exact(email),
            },
            database_connection,
        )?;

        if let Some(user) = found_users.users.pop() {
            Ok(user.id)
        } else {
            Err(Error::new(ErrorKind::GoogleUserNotFound))
        }

    } else {
         Err(Error::new(ErrorKind::GoogleUserNoEmail))
    }
}

pub fn check_to_run(
    requesting_user_id: Option<u64>,
    permission_name: &str,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    trace!(
        "Checking if user {:?} has {}",
        requesting_user_id,
        permission_name
    );
    match requesting_user_id {
        Some(user_id) => {
            match check_user_access(
                user_id,
                String::from(permission_name),
                database_connection,
            ) {
                Ok(access) => {
                    if access {
                        debug!("Access granted!");
                        Ok(())
                    } else {
                        Err(Error::new(ErrorKind::AccessDenied))
                    }
                }
                Err(e) => Err(e),
            }
        }
        None => Err(Error::new(ErrorKind::AccessDenied)),
    }
}

pub fn handle_permission(
    request: PermissionRequest,
    requesting_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<PermissionResponse, Error> {
    match request {
        PermissionRequest::FirstPermission(id_token) => {
            first_permission(requesting_user, &id_token, database_connection)
                .map(|_| PermissionResponse::NoResponse)
        }
        PermissionRequest::GetPermission(id) => {
            match check_to_run(
                requesting_user,
                "GetPermission",
                database_connection,
            ) {
                Ok(()) => get_permission(id, database_connection)
                    .map(|a| PermissionResponse::OnePermission(a)),
                Err(e) => Err(e),
            }
        }
        PermissionRequest::CreatePermission(permission) => {
            match check_to_run(
                requesting_user,
                "CreatePermission",
                database_connection,
            ) {
                Ok(()) => create_permission(permission, database_connection)
                    .map(|a| PermissionResponse::OnePermission(a)),
                Err(e) => Err(e),
            }
        }
        PermissionRequest::UpdatePermission(id, permission) => {
            match check_to_run(
                requesting_user,
                "UpdatePermission",
                database_connection,
            ) {
                Ok(()) => update_permission(id, permission, database_connection)
                    .map(|_| PermissionResponse::NoResponse),
                Err(e) => Err(e),
            }
        }
        PermissionRequest::DeletePermission(id) => {
            match check_to_run(
                requesting_user,
                "DeletePermission",
                database_connection,
            ) {
                Ok(()) => delete_permission(id, database_connection)
                    .map(|_| PermissionResponse::NoResponse),
                Err(e) => Err(e),
            }
        }
    }
}

pub(crate) fn first_permission(
    requesting_user: Option<u64>,
    id_token: &str,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    trace!(
        "First permission requested for user: {:?}, id_token: {}",
        requesting_user,
        id_token
    );

    let search = SearchUserAccess {
        permission_id: Search::NoSearch,
        user_id: Search::NoSearch,
        access_level: NullableSearch::NoSearch,
    };

    let non_root_accesses = search_user_access(search, &database_connection)?
        .entries
        .into_iter()
        .filter(|access| access.permission_id != 1)
        .count();

    trace!("Found {} non-root accesses", non_root_accesses);

    if non_root_accesses == 0 {
        let user_id = if let Some(user_id) = requesting_user {
            user_id
        } else {
            let mut client = google_signin::Client::new();
            client.audiences.push(String::from(
                    "918184954544-jm1aufr31fi6sdjs1140p7p3rouaka14.apps.googleusercontent.com",
                    ));

            let info = client.verify(id_token)?;

            trace!("Token verified: {:?}", info);

            let email = match info.email {
                Some(email) => email,
                None => {
                    return Err(Error::new(ErrorKind::AccessDenied));
                }
            };

            let new_user = NewUser {
                first_name: info
                    .given_name
                    .unwrap_or("Not supplied by Google".to_owned()),
                last_name: info
                    .family_name
                    .unwrap_or("Not supplied by Google".to_owned()),
                email: email,
                banner_id: 0,
                accesses: Vec::new(),
            };

            trace!("New user: {:#?}", new_user);

            create_user(new_user, database_connection)?.id
        };

        let permissions = permission_schema::table
            .filter(permission_schema::permission_name.ne("RootAccess"))
            .load::<Permission>(database_connection)?;

        let new_user_accesses: Vec<_> = permissions
            .into_iter()
            .map(|permission| NewUserAccess {
                permission_id: permission.id,
                user_id: user_id,
                access_level: None,
            })
            .collect();

        diesel::insert_into(user_access_schema::table)
            .values(new_user_accesses)
            .execute(database_connection)?;

        Ok(())
    } else {
        warn!("First permission request attempted, but permission has already been setup.");
        Err(Error::new(ErrorKind::AccessDenied))
    }
}

pub(crate) fn get_permission(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<Permission, Error> {
    let mut found_permission = permission_schema::table
        .filter(permission_schema::id.eq(id))
        .load::<Permission>(database_connection)?;

    match found_permission.pop() {
        Some(permission) => Ok(permission),
        None => Err(Error::new(ErrorKind::NotFound)),
    }
}

pub(crate) fn create_permission(
    permission: NewPermission,
    database_connection: &MysqlConnection,
) -> Result<Permission, Error> {
    diesel::insert_into(permission_schema::table)
        .values(permission)
        .execute(database_connection)?;

    no_arg_sql_function!(last_insert_id, Unsigned<sql_types::Bigint>);

    let mut inserted_permissions = permission_schema::table
        .filter(permission_schema::id.eq(last_insert_id))
        //.filter(diesel::dsl::sql("id = LAST_INSERT_ID()"))
        .load::<Permission>(database_connection)?;

    if let Some(inserted_permission) = inserted_permissions.pop() {
        Ok(inserted_permission)
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

pub(crate) fn update_permission(
    id: u64,
    permission: PartialPermission,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::update(permission_schema::table)
        .filter(permission_schema::id.eq(id))
        .set(&permission)
        .execute(database_connection)?;
    Ok(())
}

pub(crate) fn delete_permission(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::delete(permission_schema::table.filter(permission_schema::id.eq(id)))
        .execute(database_connection)?;

    Ok(())
}

pub fn handle_user_access(
    request: UserAccessRequest,
    requesting_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<UserAccessResponse, Error> {
    match request {
        UserAccessRequest::SearchAccess(user_access) => {
            match check_to_run(
                requesting_user,
                "GetUserAccess",
                database_connection,
            ) {
                Ok(()) => search_user_access(user_access, database_connection)
                    .map(|u| UserAccessResponse::ManyUserAccess(u)),
                Err(e) => Err(e),
            }
        }
        UserAccessRequest::GetCurrentUserAccess => {
            get_current_user_access(requesting_user, database_connection)
                .map(|u| UserAccessResponse::ManyAccess(u))
        }
        UserAccessRequest::GetAccess(permission_id) => {
            match check_to_run(
                requesting_user,
                "GetUserAccess",
                database_connection,
            ) {
                Ok(()) => get_user_access(permission_id, database_connection)
                    .map(|a| UserAccessResponse::OneUserAccess(a)),
                Err(e) => Err(e),
            }
        }
        UserAccessRequest::CheckAccess(user_id, access_name) => {
            check_user_access(user_id, access_name, database_connection)
                .map(|s| UserAccessResponse::AccessState(s))
        },
        UserAccessRequest::CreateAccess(user_access) => {
            match check_to_run(
                requesting_user,
                "CreateUserAccess",
                database_connection,
            ) {
                Ok(()) => create_user_access(user_access, database_connection)
                    .map(|a| UserAccessResponse::OneUserAccess(a)),
                Err(e) => Err(e),
            }
        }
        UserAccessRequest::UpdateAccess(id, user_access) => {
            match check_to_run(
                requesting_user,
                "UpdateUserAccess",
                database_connection,
            ) {
                Ok(()) => {
                    update_user_access(id, user_access, database_connection)
                        .map(|_| UserAccessResponse::NoResponse)
                }
                Err(e) => Err(e),
            }
        }
        UserAccessRequest::DeleteAccess(id) => {
            match check_to_run(
                requesting_user,
                "DeleteUserAccess",
                database_connection,
            ) {
                Ok(()) => delete_user_access(id, database_connection)
                    .map(|_| UserAccessResponse::NoResponse),
                Err(e) => Err(e),
            }
        }
    }
}

pub(crate) fn search_user_access(
    user_access_search: SearchUserAccess,
    database_connection: &MysqlConnection,
) -> Result<JoinedUserAccessList, Error> {
    let mut user_access_query = user_access_schema::table
        .inner_join(permission_schema::table)
        .inner_join(users_schema::table)
        .select((
            user_access_schema::permission_id,
            users_schema::id,
            permission_schema::id,
            users_schema::first_name,
            users_schema::last_name,
            users_schema::banner_id,
        ))
        .into_boxed::<Mysql>();

    match user_access_search.permission_id {
        Search::Partial(s) => {
            user_access_query =
                user_access_query.filter(user_access_schema::access_id.eq(s))
        }

        Search::Exact(s) => {
            user_access_query =
                user_access_query.filter(user_access_schema::access_id.eq(s))
        }

        Search::NoSearch => {}
    }

    match user_access_search.user_id {
        Search::Partial(s) => {
            user_access_query =
                user_access_query.filter(user_access_schema::user_id.eq(s))
        }

        Search::Exact(s) => {
            user_access_query =
                user_access_query.filter(user_access_schema::user_id.eq(s))
        }

        Search::NoSearch => {}
    }

    match user_access_search.access_level {
        NullableSearch::Partial(s) => {
            user_access_query = user_access_query.filter(
                user_access_schema::access_level.like(format!("%{}%", s)),
            )
        }

        NullableSearch::Exact(s) => {
            user_access_query = user_access_query
                .filter(user_access_schema::access_level.eq(s))
        }

        NullableSearch::Some => {
            user_access_query = user_access_query
                .filter(user_access_schema::access_level.is_not_null());
        }

        NullableSearch::None => {
            user_access_query = user_access_query
                .filter(user_access_schema::access_level.is_null());
        }

        NullableSearch::NoSearch => {}
    }

    let found_access_entries =
        user_access_query.load::<JoinedUserAccess>(database_connection)?;
    let joined_list = JoinedUserAccessList {
        entries: found_access_entries,
    };

    Ok(joined_list)
}

pub(crate) fn get_current_user_access(
    requesting_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<PermissionList, Error> {
    if let Some(user_id) = requesting_user {
        let permissions = permission_schema::table
            .inner_join(user_access_schema::table)
            .select((permission_schema::id, permission_schema::permission_name))
            .filter(user_access_schema::user_id.eq(user_id))
            .load::<Permission>(database_connection)?;

        Ok(PermissionList { permissions })
    } else {
        Err(Error::new(ErrorKind::AccessDenied))
    }
}

pub(crate) fn get_user_access(
    permission_id: u64,
    database_connection: &MysqlConnection,
) -> Result<UserAccess, Error> {
    let mut found_user_accesses = user_access_schema::table
        .filter(user_access_schema::permission_id.eq(permission_id))
        .load::<UserAccess>(database_connection)?;

    match found_user_accesses.pop() {
        Some(found_user_access) => Ok(found_user_access),
        None => Err(Error::new(ErrorKind::NotFound)),
    }
}

pub(crate) fn check_user_access(
    user_id: u64,
    permission_name: String,
    database_connection: &MysqlConnection,
) -> Result<bool, Error> {
    let found_user_accesses = user_access_schema::table
        .inner_join(permission_schema::table)
        .select((user_access_schema::user_id, permission_schema::permission_name))
        .filter(user_access_schema::user_id.eq(user_id))
        .filter(permission_schema::permission_name.eq(permission_name))
        .execute(database_connection)?;

    if found_user_accesses != 0 {
        Ok(true)
    } else {
        Ok(false)
    }
}

pub(crate) fn create_user_access(
    user_access: NewUserAccess,
    database_connection: &MysqlConnection,
) -> Result<UserAccess, Error> {
    //find if permission currently exists, should not duplicate (user_id, access_id) pairs
    let found_user_accesses = user_access_schema::table
        .filter(user_access_schema::user_id.eq(user_access.user_id))
        .filter(user_access_schema::permission_id.eq(user_access.permission_id))
        .execute(database_connection)?;

    if found_user_accesses != 0 {
        return Err(Error::new(ErrorKind::Database));
    }

    //permission most definitely does not exist at this point

    diesel::insert_into(user_access_schema::table)
        .values(user_access)
        .execute(database_connection)?;

    no_arg_sql_function!(last_insert_id, Unsigned<sql_types::Bigint>);

    let mut inserted_accesses = user_access_schema::table
        .filter(user_access_schema::permission_id.eq(last_insert_id))
        //.filter(diesel::dsl::sql("permission_id = LAST_INSERT_ID()"))
        .load::<UserAccess>(database_connection)?;

    if let Some(inserted_access) = inserted_accesses.pop() {
        Ok(inserted_access)
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

pub(crate) fn update_user_access(
    id: u64,
    user_access: PartialUserAccess,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::update(user_access_schema::table)
        .filter(user_access_schema::permission_id.eq(id))
        .set(&user_access)
        .execute(database_connection)?;

    Ok(())
}

pub(crate) fn delete_user_access(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::delete(
        user_access_schema::table
            .filter(user_access_schema::permission_id.eq(id)),
    )
    .execute(database_connection)?;

    Ok(())
}
