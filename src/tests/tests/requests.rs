use diesel;
use diesel::mysql::MysqlConnection;
use diesel::ExpressionMethods;
use diesel::QueryDsl;
use diesel::RunQueryDsl;

use crate::errors::Error;
use crate::errors::ErrorKind;

use crate::access::requests::check_to_run;

use crate::tests::tests::models::{
    JoinedTest, NewRawTest, NewTest, RawTest, RawTestQuestionCategory, Test,
    TestList, TestQuestionCategory, TestRequest, TestResponse,
};
use crate::tests::tests::schema::test_question_categories as test_question_categories_schema;
use crate::tests::tests::schema::tests as tests_schema;

pub fn handle_test(
    request: TestRequest,
    requested_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<TestResponse, Error> {
    match request {
        TestRequest::GetTests => {
            check_to_run(requested_user, "GetTests", database_connection)?;
            get_tests(database_connection).map(|u| TestResponse::ManyTests(u))
        }
        TestRequest::GetTest(id) => {
            check_to_run(requested_user, "GetTests", database_connection)?;
            get_test(id, database_connection).map(|u| TestResponse::OneTest(u))
        }
        TestRequest::CreateTest(test) => {
            check_to_run(requested_user, "CreateTests", database_connection)?;
            create_test(test, requested_user, database_connection)
                .map(|u| TestResponse::OneTest(u))
        }
        TestRequest::DeleteTest(id) => {
            check_to_run(requested_user, "DeleteTests", database_connection)?;
            delete_test(id, database_connection)
                .map(|_| TestResponse::NoResponse)
        }
    }
}

pub(crate) fn get_tests(
    database_connection: &MysqlConnection,
) -> Result<TestList, Error> {
    let joined_tests = tests_schema::table
        .inner_join(test_question_categories_schema::table)
        .select((
            tests_schema::id,
            tests_schema::creator_id,
            tests_schema::name,
            test_question_categories_schema::test_id,
            test_question_categories_schema::question_category_id,
            test_question_categories_schema::number_of_questions,
        ))
        .load::<JoinedTest>(database_connection)?;

    let mut tests: Vec<Test> = Vec::new();

    for joined_test in joined_tests {
        if let Some(test) = tests.iter_mut().find(|t| t.id == joined_test.id) {
            test.questions.push(TestQuestionCategory {
                question_category_id: joined_test.question_category_id,
                number_of_questions: joined_test.number_of_questions,
            });
        } else {
            let test = Test {
                id: joined_test.id,
                creator_id: joined_test.creator_id,
                name: joined_test.name,
                questions: vec![TestQuestionCategory {
                    question_category_id: joined_test.question_category_id,
                    number_of_questions: joined_test.number_of_questions,
                }],
            };

            tests.push(test);
        }
    }

    Ok(TestList { tests })
}

pub(crate) fn create_test(
    test: NewTest,
    requesting_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<Test, Error> {
    let creator_id = match requesting_user {
        Some(user) => user,
        None => return Err(Error::new(ErrorKind::AccessDenied)),
    };

    let new_raw_test = NewRawTest {
        creator_id: creator_id,
        name: test.name,
    };

    diesel::insert_into(tests_schema::table)
        .values(new_raw_test)
        .execute(database_connection)?;

    let mut raw_inserted_tests = tests_schema::table
        .filter(diesel::dsl::sql("id = LAST_INSERT_ID()"))
        .load::<RawTest>(database_connection)?;

    if let Some(raw_inserted_test) = raw_inserted_tests.pop() {
        let test_question_categories: Vec<_> = test
            .questions
            .iter()
            .map(|test_question_category| RawTestQuestionCategory {
                test_id: raw_inserted_test.id,
                number_of_questions: test_question_category.number_of_questions,
                question_category_id: test_question_category
                    .question_category_id,
            })
            .collect();

        diesel::insert_into(test_question_categories_schema::table)
            .values(test_question_categories)
            .execute(database_connection)?;

        let inserted_test_question_categories =
            test_question_categories_schema::table
                .filter(
                    test_question_categories_schema::test_id
                        .eq(raw_inserted_test.id),
                )
                .load::<RawTestQuestionCategory>(database_connection)?
                .iter()
                .map(|raw_test_question_category| TestQuestionCategory {
                    number_of_questions: raw_test_question_category
                        .number_of_questions,
                    question_category_id: raw_test_question_category
                        .question_category_id,
                })
                .collect();

        let inserted_test = Test {
            id: raw_inserted_test.id,
            creator_id: raw_inserted_test.creator_id,
            name: raw_inserted_test.name,
            questions: inserted_test_question_categories,
        };

        Ok(inserted_test)
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

pub(crate) fn get_test(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<Test, Error> {
    let mut joined_tests = tests_schema::table
        .inner_join(test_question_categories_schema::table)
        .filter(tests_schema::id.eq(id))
        .select((
            tests_schema::id,
            tests_schema::creator_id,
            tests_schema::name,
            test_question_categories_schema::test_id,
            test_question_categories_schema::question_category_id,
            test_question_categories_schema::number_of_questions,
        ))
        .load::<JoinedTest>(database_connection)?;

    if let Some(first_joined_test) = joined_tests.pop() {
        let mut test = Test {
            id: first_joined_test.id,
            creator_id: first_joined_test.creator_id,
            name: first_joined_test.name,
            questions: vec![TestQuestionCategory {
                question_category_id: first_joined_test.question_category_id,
                number_of_questions: first_joined_test.number_of_questions,
            }],
        };

        for joined_test in joined_tests {
            test.questions.push(TestQuestionCategory {
                question_category_id: joined_test.question_category_id,
                number_of_questions: joined_test.number_of_questions,
            });
        }

        Ok(test)
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

pub(crate) fn delete_test(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::delete(tests_schema::table.filter(tests_schema::id.eq(id)))
        .execute(database_connection)?;

    Ok(())
}
