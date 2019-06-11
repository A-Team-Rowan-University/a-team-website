use diesel;
use diesel::mysql::MysqlConnection;
use diesel::ExpressionMethods;
use diesel::NullableExpressionMethods;
use diesel::QueryDsl;
use diesel::RunQueryDsl;

use crate::errors::Error;
use crate::errors::ErrorKind;

use crate::access::requests::check_to_run;

use crate::tests::question_categories::models::{
    JoinedQuestionCategory, NewQuestionCategory, NewRawQuestionCategory,
    QuestionCategory, QuestionCategoryList, QuestionCategoryRequest,
    QuestionCategoryResponse, RawQuestionCategory,
};

use crate::tests::questions::models::NewRawQuestion;
use crate::tests::questions::models::Question;

use crate::tests::question_categories::schema::question_categories as question_categories_schema;
use crate::tests::questions::schema::questions as questions_schema;

pub fn handle_question_category(
    request: QuestionCategoryRequest,
    requested_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<QuestionCategoryResponse, Error> {
    match request {
        QuestionCategoryRequest::GetQuestionCategories => {
            check_to_run(
                requested_user,
                "GetQuestionCategories",
                database_connection,
            )?;
            get_question_categories(database_connection)
                .map(|u| QuestionCategoryResponse::ManyQuestionCategories(u))
        }
        QuestionCategoryRequest::GetQuestionCategory(id) => {
            check_to_run(
                requested_user,
                "GetQuestionCategories",
                database_connection,
            )?;
            get_question_category(id, database_connection)
                .map(|u| QuestionCategoryResponse::OneQuestionCategory(u))
        }
        QuestionCategoryRequest::CreateQuestionCategory(question_category) => {
            check_to_run(
                requested_user,
                "CreateQuestionCategories",
                database_connection,
            )?;
            create_question_category(question_category, database_connection)
                .map(|u| QuestionCategoryResponse::OneQuestionCategory(u))
        }
        QuestionCategoryRequest::DeleteQuestionCategory(id) => {
            check_to_run(
                requested_user,
                "DeleteQuestionCategories",
                database_connection,
            )?;
            delete_question_category(id, database_connection)
                .map(|_| QuestionCategoryResponse::NoResponse)
        }
    }
}

pub(crate) fn condense_join(
    joined: Vec<JoinedQuestionCategory>,
) -> Result<Vec<QuestionCategory>, Error> {
    let mut condensed: Vec<QuestionCategory> = Vec::new();

    for join in joined {
        let mut question = if let Some(question) = &join.question {
            vec![question.clone()]
        } else {
            Vec::new()
        };

        if let Some(question_category) = condensed
            .iter_mut()
            .find(|t| t.id == join.question_category.id)
        {
            question_category.questions.append(&mut question);
        } else {
            let question_category = QuestionCategory {
                id: join.question_category.id,
                title: join.question_category.title,
                questions: question,
            };

            condensed.push(question_category);
        }
    }
    Ok(condensed)
}

pub(crate) fn get_question_category(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<QuestionCategory, Error> {
    let joined_question_categories = question_categories_schema::table
        .left_join(questions_schema::table)
        .select((
            (
                question_categories_schema::id,
                question_categories_schema::title,
            ),
            (
                questions_schema::id,
                questions_schema::category_id,
                questions_schema::title,
                questions_schema::correct_answer,
                questions_schema::incorrect_answer_1,
                questions_schema::incorrect_answer_2,
                questions_schema::incorrect_answer_3,
            )
                .nullable(),
        ))
        .filter(question_categories_schema::id.eq(id))
        .load::<JoinedQuestionCategory>(database_connection)?;

    let mut question_categories = condense_join(joined_question_categories)?;

    if let Some(question_category) = question_categories.pop() {
        Ok(question_category)
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

pub(crate) fn get_question_categories(
    database_connection: &MysqlConnection,
) -> Result<QuestionCategoryList, Error> {
    let joined_question_categories = question_categories_schema::table
        .left_join(questions_schema::table)
        .select((
            (
                question_categories_schema::id,
                question_categories_schema::title,
            ),
            (
                questions_schema::id,
                questions_schema::category_id,
                questions_schema::title,
                questions_schema::correct_answer,
                questions_schema::incorrect_answer_1,
                questions_schema::incorrect_answer_2,
                questions_schema::incorrect_answer_3,
            )
                .nullable(),
        ))
        .load::<JoinedQuestionCategory>(database_connection)?;

    let question_categories = condense_join(joined_question_categories)?;

    Ok(QuestionCategoryList {
        question_categories,
    })
}

pub(crate) fn create_question_category(
    question_category: NewQuestionCategory,
    database_connection: &MysqlConnection,
) -> Result<QuestionCategory, Error> {
    let new_raw_question_category = NewRawQuestionCategory {
        title: question_category.title,
    };

    diesel::insert_into(question_categories_schema::table)
        .values(new_raw_question_category)
        .execute(database_connection)?;

    let mut raw_inserted_question_categories =
        question_categories_schema::table
            .filter(diesel::dsl::sql("id = LAST_INSERT_ID()"))
            .load::<RawQuestionCategory>(database_connection)?;

    if let Some(raw_inserted_question_category) =
        raw_inserted_question_categories.pop()
    {
        let new_raw_questions: Vec<_> = question_category
            .questions
            .into_iter()
            .map(|question| NewRawQuestion {
                title: question.title,
                category_id: raw_inserted_question_category.id,
                correct_answer: question.correct_answer,
                incorrect_answer_1: question.incorrect_answer_1,
                incorrect_answer_2: question.incorrect_answer_2,
                incorrect_answer_3: question.incorrect_answer_3,
            })
            .collect();

        diesel::insert_into(questions_schema::table)
            .values(new_raw_questions)
            .execute(database_connection)?;

        let inserted_questions = questions_schema::table
            .filter(
                questions_schema::category_id
                    .eq(raw_inserted_question_category.id),
            )
            .load::<Question>(database_connection)?
            .into_iter()
            .map(|raw_question| Question {
                id: raw_question.id,
                category_id: raw_question.category_id,
                title: raw_question.title,
                correct_answer: raw_question.correct_answer,
                incorrect_answer_1: raw_question.incorrect_answer_1,
                incorrect_answer_2: raw_question.incorrect_answer_2,
                incorrect_answer_3: raw_question.incorrect_answer_3,
            })
            .collect();

        let inserted_question_category = QuestionCategory {
            id: raw_inserted_question_category.id,
            title: raw_inserted_question_category.title,
            questions: inserted_questions,
        };

        Ok(inserted_question_category)
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

pub(crate) fn delete_question_category(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::delete(
        question_categories_schema::table
            .filter(question_categories_schema::id.eq(id)),
    )
    .execute(database_connection)?;

    Ok(())
}
