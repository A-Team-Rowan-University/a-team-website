table! {
    tests (id) {
        id -> Unsigned<Bigint>,
        creator_id -> Unsigned<Bigint>,
        name -> Varchar,
    }
}

table! {
    test_question_categories (test_id, question_category_id) {
        test_id -> Unsigned<Bigint>,
        question_category_id -> Unsigned<Bigint>,
        number_of_questions -> Unsigned<Integer>,
    }
}

joinable!(test_question_categories -> tests (test_id));
allow_tables_to_appear_in_same_query!(tests, test_question_categories);
