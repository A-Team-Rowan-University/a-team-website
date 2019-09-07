table! {
    users (id) {
        id -> Unsigned<Bigint>,
        first_name -> Varchar,
        last_name -> Varchar,
        banner_id -> Unsigned<Integer>,
        email -> Varchar,
    }
}
