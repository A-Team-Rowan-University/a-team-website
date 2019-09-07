use crate::tests::questions::schema::questions;

table! {
    question_categories (id) {
        id -> Unsigned<Bigint>,
        title -> Varchar,
    }
}

joinable!(questions -> question_categories (category_id));
allow_tables_to_appear_in_same_query!(question_categories, questions);
