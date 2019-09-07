table! {
    questions (id) {
        id -> Unsigned<Bigint>,
        category_id -> Unsigned<Bigint>,
        title -> Varchar,
        correct_answer -> Varchar,
        incorrect_answer_1 -> Varchar,
        incorrect_answer_2 -> Varchar,
        incorrect_answer_3 -> Varchar,
    }
}
