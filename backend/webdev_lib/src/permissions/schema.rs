use crate::users::schema::users;

table! {
    permissions (id) {
        id -> Unsigned<Bigint>,
        permission_name -> Varchar,
    }
}

table! {
    user_permissions (user_permission_id) {
        user_permission_id -> Unsigned<Bigint>,
        permission_id -> Unsigned<Bigint>,
        user_id -> Unsigned<Bigint>,
    }
}

joinable!(user_permissions -> permissions (permission_id));
joinable!(user_permissions -> users (user_id));

allow_tables_to_appear_in_same_query!(permissions, user_permissions, users,);
