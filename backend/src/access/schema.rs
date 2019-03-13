use diesel::table;

use crate::users::schema::users;

table! {
    access (id) {
        id -> Bigint,
        access_name -> Varchar,
    }
}

table! {
    user_access (permission_id) {
        permission_id -> Bigint,
        access_id -> Bigint,
        user_id -> Bigint,
        permission_level -> Nullable<Varchar>,
    }
}

joinable!(user_access -> access (access_id));
joinable!(user_access -> users (user_id));

allow_tables_to_appear_in_same_query!(
    access,
    user_access,
    users,
);
