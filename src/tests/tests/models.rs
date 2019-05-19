use rouille;
use rouille::router;
use serde::Deserialize;
use serde::Serialize;
use serde_json;

use log::warn;

use crate::errors::Error;
use crate::errors::ErrorKind;

use super::schema::test_question_categories;
use super::schema::tests;

#[derive(Queryable, Debug)]
pub struct RawTest {
    pub id: u64,
    pub creator_id: u64,
    pub name: String,
}

#[derive(Insertable)]
#[table_name = "tests"]
pub struct NewRawTest {
    pub creator_id: u64,
    pub name: String,
}

#[derive(Queryable, Insertable, Debug)]
#[table_name = "test_question_categories"]
pub struct RawTestQuestionCategory {
    pub test_id: u64,
    pub question_category_id: u64,
    pub number_of_questions: u32,
}

#[derive(Queryable, Debug)]
pub struct JoinedTest {
    pub id: u64,
    pub creator_id: u64,
    pub name: String,
    pub test_id: u64,
    pub question_category_id: u64,
    pub number_of_questions: u32,
}

#[derive(Serialize, Deserialize)]
pub struct Test {
    pub id: u64,
    pub creator_id: u64,
    pub name: String,
    pub questions: Vec<TestQuestionCategory>,
}

#[derive(Serialize, Deserialize)]
pub struct TestQuestionCategory {
    pub question_category_id: u64,
    pub number_of_questions: u32,
}

#[derive(Serialize, Deserialize)]
pub struct NewTest {
    pub name: String,
    pub questions: Vec<TestQuestionCategory>,
}

#[derive(Serialize, Deserialize)]
pub struct TestList {
    pub tests: Vec<Test>,
}

pub enum TestRequest {
    GetTests,
    GetTest(u64),
    CreateTest(NewTest),
    DeleteTest(u64),
}

impl TestRequest {
    pub fn from_rouille(
        request: &rouille::Request,
    ) -> Result<TestRequest, Error> {
        router!(request,
            (GET) (/) => {
                Ok(TestRequest::GetTests)
            },

            (GET) (/{id: u64}) => {
                Ok(TestRequest::GetTest(id))
            },

            (POST) (/) => {
                let request_body = request.data().ok_or(Error::new(ErrorKind::Body))?;
                let new_test: NewTest = serde_json::from_reader(request_body)?;

                Ok(TestRequest::CreateTest(new_test))
            },

            (DELETE) (/{id: u64}) => {
                Ok(TestRequest::DeleteTest(id))
            },

            _ => {
                warn!("Could not create a test request for the given rouille request");
                Err(Error::new(ErrorKind::NotFound))
            }
        )
    }
}

pub enum TestResponse {
    OneTest(Test),
    ManyTests(TestList),
    NoResponse,
}

impl TestResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            TestResponse::OneTest(test) => rouille::Response::json(&test),
            TestResponse::ManyTests(tests) => rouille::Response::json(&tests),
            TestResponse::NoResponse => rouille::Response::empty_204(),
        }
    }
}
