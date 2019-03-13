table! {
    users (id) {
        id -> Bigint,
        first_name -> Varchar,
        last_name -> Varchar,
        banner_id -> Unsigned<Integer>,
        email -> Nullable<Varchar>,
    }
}
