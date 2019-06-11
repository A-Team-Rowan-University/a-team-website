table! {
    test_sessions (id) {
        id -> Unsigned<Bigint>,
        test_id -> Unsigned<Bigint>,
        name -> Varchar,
        registrations_enabled -> Bool,
        opening_enabled -> Bool,
        submissions_enabled -> Bool,
    }
}

table! {
    test_session_registrations (id) {
        id -> Unsigned<Bigint>,
        test_session_id -> Unsigned<Bigint>,
        taker_id -> Unsigned<Bigint>,
        registered -> Timestamp,
        opened_test -> Nullable<Timestamp>,
        submitted_test -> Nullable<Timestamp>,
        score -> Nullable<Float>,
    }
}

joinable!(test_session_registrations -> test_sessions (test_session_id));
allow_tables_to_appear_in_same_query!(
    test_sessions,
    test_session_registrations
);
