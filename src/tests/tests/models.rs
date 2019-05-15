use rouille;
use rouille::router;
use serde::Deserialize;
use serde::Serialize;
use serde_json;

use log::warn;

use crate::errors::Error;
use crate::errors::ErrorKind;

use super::schema::tests;

#[derive(Queryable, Serialize, Deserialize)]
pub struct Test {
    pub id: u64,
    pub creator_id: u64,
    pub name: String,
}

#[derive(Insertable, Serialize, Deserialize)]
#[table_name = "tests"]
pub struct NewTest {
    pub creator_id: u64,
    pub name: String,
}

#[derive(Serialize, Deserialize)]
pub struct TestList {
    pub tests: Vec<Test>,
}

pub enum TestRequest {
    GetTests,
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
            TestResponse::OneTest(test) => {
                rouille::Response::json(&test)
            }
            TestResponse::ManyTests(tests) => {
                rouille::Response::json(&tests)
            }
            TestResponse::NoResponse => rouille::Response::empty_204(),
        }
    }
}
