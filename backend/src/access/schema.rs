table! {
    access (id) {
        id -> Unsigned<Bigint>,
        access_name -> Varchar,
    }
}

table! {
    user_access (permission_id) {
        permission_id -> Unsigned<Integer>,
        access_id -> Unsigned<Bigint>,
        user_id -> Unsigned<Bigint>,
        permission_level -> Nullable<Varchar>,
    }
}

use crate::users::schema::users;

joinable!(user_access -> access (access_id));
joinable!(user_access -> users (user_id));

allow_tables_to_appear_in_same_query!(
    access,
    user_access,
    users,
);
