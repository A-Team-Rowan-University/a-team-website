use crate::users::schema::users;

table! {
    permission (id) {
        id -> Unsigned<Bigint>,
        permission_name -> Varchar,
    }
}

table! {
    user_access (permission_id) {
        access_id -> Unsigned<Bigint>,
        permission_id -> Unsigned<Bigint>,
        user_id -> Unsigned<Bigint>,
        access_level -> Nullable<Varchar>,
    }
}

joinable!(user_access -> permission (permission_id));
joinable!(user_access -> users (user_id));

allow_tables_to_appear_in_same_query!(permission, user_access, users,);
