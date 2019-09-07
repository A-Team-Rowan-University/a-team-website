use diesel;
use diesel::mysql::types::Unsigned;
use diesel::mysql::Mysql;
use diesel::mysql::MysqlConnection;
use diesel::sql_types;
use diesel::ExpressionMethods;
use diesel::QueryDsl;
use diesel::RunQueryDsl;

use google_signin;

use log::debug;
use log::trace;
use log::warn;

use crate::errors::{Error, ErrorKind};

use crate::search::Search;

use super::models::{
    JoinedUserPermission, JoinedUserPermissionList, NewPermission,
    NewUserPermission, PartialPermission, PartialUserPermission, Permission,
    PermissionList, PermissionRequest, PermissionResponse,
    SearchUserPermission, UserPermission, UserPermissionRequest,
    UserPermissionResponse
};

use crate::users::models::{NewUser, SearchUser};
use crate::users::requests::create_user;
use crate::users::requests::search_users;

use super::schema::permissions as permissions_schema;
use super::schema::user_permissions as user_permissions_schema;
use crate::users::schema::users as users_schema;

pub fn validate_token(id_token: &str, database_connection: &MysqlConnection) -> Result<u64, Error> {
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
            match check_user_permission(user_id, String::from(permission_name), database_connection)
            {
                Ok(permission) => {
                    if permission {
                        debug!("Permission granted!");
                        Ok(())
                    } else {
                        Err(Error::new(ErrorKind::PermissionDenied))
                    }
                }
                Err(e) => Err(e),
            }
        }
        None => Err(Error::new(ErrorKind::PermissionDenied)),
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
            match check_to_run(requesting_user, "GetPermission", database_connection) {
                Ok(()) => get_permission(id, database_connection)
                    .map(|a| PermissionResponse::OnePermission(a)),
                Err(e) => Err(e),
            }
        }
        PermissionRequest::CreatePermission(permission) => {
            match check_to_run(requesting_user, "CreatePermission", database_connection) {
                Ok(()) => create_permission(permission, database_connection)
                    .map(|a| PermissionResponse::OnePermission(a)),
                Err(e) => Err(e),
            }
        }
        PermissionRequest::UpdatePermission(id, permission) => {
            match check_to_run(requesting_user, "UpdatePermission", database_connection) {
                Ok(()) => update_permission(id, permission, database_connection)
                    .map(|_| PermissionResponse::NoResponse),
                Err(e) => Err(e),
            }
        }
        PermissionRequest::DeletePermission(id) => {
            match check_to_run(requesting_user, "DeletePermission", database_connection) {
                Ok(()) => delete_permission(id, database_connection)
                    .map(|_| PermissionResponse::NoResponse),
                Err(e) => Err(e),
            }
        }
        PermissionRequest::GetPermissions => {
            get_permissions(database_connection)
                .map(|u| PermissionResponse::ManyPermissions(u))
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

    let search = SearchUserPermission {
        permission_id: Search::NoSearch,
        user_id: Search::NoSearch,
    };

    let non_root_permissions = search_user_permission(search, &database_connection)?
        .entries
        .into_iter()
        .filter(|permission| permission.permission_id != 1)
        .count();

    trace!("Found {} non-root permissions", non_root_permissions);

    if non_root_permissions == 0 {
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
                    return Err(Error::new(ErrorKind::PermissionDenied));
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
                permissions: Vec::new(),
            };

            trace!("New user: {:#?}", new_user);

            create_user(new_user, database_connection)?.id
        };

        let permissions = permissions_schema::table
            .filter(permissions_schema::permission_name.ne("RootPermission"))
            .load::<Permission>(database_connection)?;

        let new_user_permissions: Vec<_> = permissions
            .into_iter()
            .map(|permission| NewUserPermission {
                permission_id: permission.id,
                user_id: user_id,
            })
            .collect();

        diesel::insert_into(user_permissions_schema::table)
            .values(new_user_permissions)
            .execute(database_connection)?;

        Ok(())
    } else {
        warn!("First permission request attempted, but permission has already been setup.");
        Err(Error::new(ErrorKind::PermissionDenied))
    }
}

pub(crate) fn get_permission(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<Permission, Error> {
    let mut found_permission = permissions_schema::table
        .filter(permissions_schema::id.eq(id))
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
    diesel::insert_into(permissions_schema::table)
        .values(permission)
        .execute(database_connection)?;

    no_arg_sql_function!(last_insert_id, Unsigned<sql_types::Bigint>);

    let mut inserted_permissions = permissions_schema::table
        .filter(permissions_schema::id.eq(last_insert_id))
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
    diesel::update(permissions_schema::table)
        .filter(permissions_schema::id.eq(id))
        .set(&permission)
        .execute(database_connection)?;
    Ok(())
}

pub(crate) fn delete_permission(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::delete(permissions_schema::table.filter(permissions_schema::id.eq(id)))
        .execute(database_connection)?;

    Ok(())
}

pub fn handle_user_permission(
    request: UserPermissionRequest,
    requesting_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<UserPermissionResponse, Error> {
    match request {
        UserPermissionRequest::SearchPermission(user_permission) => {
            match check_to_run(requesting_user, "GetUserPermission", database_connection) {
                Ok(()) => search_user_permission(user_permission, database_connection)
                    .map(|u| UserPermissionResponse::ManyUserPermission(u)),
                Err(e) => Err(e),
            }
        }
        UserPermissionRequest::GetCurrentUserPermission => {
            get_current_user_permission(requesting_user, database_connection)
                .map(|u| UserPermissionResponse::ManyPermission(u))
        }
        UserPermissionRequest::GetPermission(permission_id) => {
            match check_to_run(requesting_user, "GetUserPermission", database_connection) {
                Ok(()) => get_user_permission(permission_id, database_connection)
                    .map(|a| UserPermissionResponse::OneUserPermission(a)),
                Err(e) => Err(e),
            }
        }
        UserPermissionRequest::CheckPermission(user_id, permission_name) => {
            check_user_permission(user_id, permission_name, database_connection)
                .map(|s| UserPermissionResponse::PermissionState(s))
        }
        UserPermissionRequest::CreatePermission(user_permission) => {
            match check_to_run(requesting_user, "CreateUserPermission", database_connection) {
                Ok(()) => create_user_permission(user_permission, database_connection)
                    .map(|a| UserPermissionResponse::OneUserPermission(a)),
                Err(e) => Err(e),
            }
        }
        UserPermissionRequest::UpdatePermission(id, user_permission) => {
            match check_to_run(requesting_user, "UpdateUserPermission", database_connection) {
                Ok(()) => update_user_permission(id, user_permission, database_connection)
                    .map(|_| UserPermissionResponse::NoResponse),
                Err(e) => Err(e),
            }
        }
        UserPermissionRequest::DeletePermission(id) => {
            match check_to_run(requesting_user, "DeleteUserPermission", database_connection) {
                Ok(()) => delete_user_permission(id, database_connection)
                    .map(|_| UserPermissionResponse::NoResponse),
                Err(e) => Err(e),
            }
        }
    }
}

pub(crate) fn search_user_permission(
    user_permission_search: SearchUserPermission,
    database_connection: &MysqlConnection,
) -> Result<JoinedUserPermissionList, Error> {
    let mut user_permission_query = user_permissions_schema::table
        .inner_join(permissions_schema::table)
        .inner_join(users_schema::table)
        .select((
            user_permissions_schema::permission_id,
            users_schema::id,
            permissions_schema::id,
            users_schema::first_name,
            users_schema::last_name,
            users_schema::banner_id,
        ))
        .into_boxed::<Mysql>();

    match user_permission_search.permission_id {
        Search::Partial(s) => {
            user_permission_query =
                user_permission_query.filter(user_permissions_schema::permission_id.eq(s))
        }

        Search::Exact(s) => {
            user_permission_query =
                user_permission_query.filter(user_permissions_schema::permission_id.eq(s))
        }

        Search::NoSearch => {}
    }

    match user_permission_search.user_id {
        Search::Partial(s) => {
            user_permission_query =
                user_permission_query.filter(user_permissions_schema::user_id.eq(s))
        }

        Search::Exact(s) => {
            user_permission_query =
                user_permission_query.filter(user_permissions_schema::user_id.eq(s))
        }

        Search::NoSearch => {}
    }

    let found_permission_entries =
        user_permission_query.load::<JoinedUserPermission>(database_connection)?;
    let joined_list = JoinedUserPermissionList {
        entries: found_permission_entries,
    };

    Ok(joined_list)
}

pub(crate) fn get_current_user_permission(
    requesting_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<PermissionList, Error> {
    if let Some(user_id) = requesting_user {
        let permissions = permissions_schema::table
            .inner_join(user_permissions_schema::table)
            .select((permissions_schema::id, permissions_schema::permission_name))
            .filter(user_permissions_schema::user_id.eq(user_id))
            .load::<Permission>(database_connection)?;

        Ok(PermissionList { permissions })
    } else {
        Err(Error::new(ErrorKind::PermissionDenied))
    }
}

pub(crate) fn get_user_permission(
    permission_id: u64,
    database_connection: &MysqlConnection,
) -> Result<UserPermission, Error> {
    let mut found_user_permissions = user_permissions_schema::table
        .filter(user_permissions_schema::permission_id.eq(permission_id))
        .load::<UserPermission>(database_connection)?;

    match found_user_permissions.pop() {
        Some(found_user_permission) => Ok(found_user_permission),
        None => Err(Error::new(ErrorKind::NotFound)),
    }
}

pub(crate) fn check_user_permission(
    user_id: u64,
    permission_name: String,
    database_connection: &MysqlConnection,
) -> Result<bool, Error> {
    let found_user_permissions = user_permissions_schema::table
        .inner_join(permissions_schema::table)
        .select((
            user_permissions_schema::user_id,
            permissions_schema::permission_name,
        ))
        .filter(user_permissions_schema::user_id.eq(user_id))
        .filter(permissions_schema::permission_name.eq(permission_name))
        .execute(database_connection)?;

    if found_user_permissions != 0 {
        Ok(true)
    } else {
        Ok(false)
    }
}

pub(crate) fn create_user_permission(
    user_permission: NewUserPermission,
    database_connection: &MysqlConnection,
) -> Result<UserPermission, Error> {
    //find if permission currently exists, should not duplicate (user_id, permission_id) pairs
    let found_user_permissions = user_permissions_schema::table
        .filter(user_permissions_schema::user_id.eq(user_permission.user_id))
        .filter(user_permissions_schema::permission_id.eq(user_permission.permission_id))
        .execute(database_connection)?;

    if found_user_permissions != 0 {
        return Err(Error::new(ErrorKind::Database));
    }

    //permission most definitely does not exist at this point

    diesel::insert_into(user_permissions_schema::table)
        .values(user_permission)
        .execute(database_connection)?;

    no_arg_sql_function!(last_insert_id, Unsigned<sql_types::Bigint>);

    let mut inserted_permissions = user_permissions_schema::table
        .filter(user_permissions_schema::user_permission_id.eq(last_insert_id))
        //.filter(diesel::dsl::sql("permission_id = LAST_INSERT_ID()"))
        .load::<UserPermission>(database_connection)?;

    if let Some(inserted_permission) = inserted_permissions.pop() {
        Ok(inserted_permission)
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

pub(crate) fn update_user_permission(
    id: u64,
    user_permission: PartialUserPermission,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::update(user_permissions_schema::table)
        .filter(user_permissions_schema::permission_id.eq(id))
        .set(&user_permission)
        .execute(database_connection)?;

    Ok(())
}

pub(crate) fn delete_user_permission(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::delete(
        user_permissions_schema::table.filter(user_permissions_schema::permission_id.eq(id)),
    )
    .execute(database_connection)?;

    Ok(())
}

pub(crate) fn get_permissions(
    database_connection: &MysqlConnection
) -> Result<PermissionList, Error> {
    let permissions = permissions_schema::table // builds a sql query to select all entrys from the permissions table
        .select((
            permissions_schema::id,
            permissions_schema::permission_name,
        ))
        .load::<Permission>(database_connection)?;
    Ok(PermissionList { permissions })
}
