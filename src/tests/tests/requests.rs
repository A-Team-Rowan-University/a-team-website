use diesel;
use diesel::mysql::MysqlConnection;
use diesel::ExpressionMethods;
use diesel::QueryDsl;
use diesel::RunQueryDsl;

use crate::errors::Error;
use crate::errors::ErrorKind;

use crate::tests::tests::models::{
    NewTest, Test, TestList, TestRequest, TestResponse,
};
use crate::tests::tests::schema::tests as tests_schema;

pub fn handle_test(
    request: TestRequest,
    database_connection: &MysqlConnection,
) -> Result<TestResponse, Error> {
    match request {
        TestRequest::GetTests => get_tests(database_connection)
            .map(|u| TestResponse::ManyTests(u)),
        TestRequest::CreateTest(test) => {
            create_test(test, database_connection)
                .map(|u| TestResponse::OneTest(u))
        }
        TestRequest::DeleteTest(id) => {
            delete_test(id, database_connection)
                .map(|_| TestResponse::NoResponse)
        }
    }
}

fn get_tests(
    database_connection: &MysqlConnection,
) -> Result<TestList, Error> {
    let found_tests =
        tests_schema::table.load::<Test>(database_connection)?;

    Ok(TestList {
        tests: found_tests,
    })
}

fn create_test(
    test: NewTest,
    database_connection: &MysqlConnection,
) -> Result<Test, Error> {
    diesel::insert_into(tests_schema::table)
        .values(test)
        .execute(database_connection)?;

    let mut inserted_tests = tests_schema::table
        .filter(diesel::dsl::sql("id = LAST_INSERT_ID()"))
        .load::<Test>(database_connection)?;

    if let Some(inserted_test) = inserted_tests.pop() {
        Ok(inserted_test)
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

fn delete_test(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::delete(tests_schema::table.filter(tests_schema::id.eq(id)))
        .execute(database_connection)?;

    Ok(())
}
