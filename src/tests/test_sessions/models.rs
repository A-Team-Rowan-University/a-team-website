use rouille;
use rouille::router;
use serde::Deserialize;
use serde::Serialize;
use serde_json;

use url::form_urlencoded;

use chrono::offset::Local;
use chrono::DateTime;
use chrono::NaiveDateTime;

use log::warn;

use crate::errors::Error;
use crate::errors::ErrorKind;

use super::schema::test_sessions;
use super::schema::test_session_registrations;

#[derive(Queryable, Debug)]
pub struct RawTestSession {
    pub id: u64,
    pub test_id: u64,
    pub name: String,
    pub registrations_enabled: bool,
    pub opening_enabled: bool,
    pub submissions_enabled: bool,
}

#[derive(Insertable, Debug)]
#[table_name = "test_sessions"]
pub struct NewRawTestSession {
    pub test_id: u64,
    pub name: String,
    pub registrations_enabled: bool,
    pub opening_enabled: bool,
    pub submissions_enabled: bool,
}

#[derive(Queryable, Debug)]
pub struct RawTestSessionRegistration {
    pub id: u64,
    pub test_session_id: u64,
    pub taker_id: u64,
    pub registered: NaiveDateTime,
    pub opened_test: Option<NaiveDateTime>,
    pub submitted_test: Option<NaiveDateTime>,
}

#[derive(Insertable, Debug)]
#[table_name = "test_session_registrations"]
pub struct NewRawTestSessionRegistration {
    pub test_session_id: u64,
    pub taker_id: u64,
    pub registered: NaiveDateTime,
    pub opened_test: Option<NaiveDateTime>,
    pub submitted_test: Option<NaiveDateTime>,
}

/*
#[derive(Queryable, Debug)]
pub struct JoinedTestSession {
    pub id: u64,
    pub test_id: u64,
    pub name: String,
    pub registrations_enabled: bool,
    pub opening_enabled: bool,
    pub submissions_enabled: bool,
    pub test_session_registration_id: Option<u64>,
    pub taker_id: Option<u64>,
    pub registered: Option<NaiveDateTime>,
    pub opened_test: Option<Option<NaiveDateTime>>,
    pub submitted_test: Option<Option<NaiveDateTime>>,
}
*/

#[derive(Queryable, Debug)]
pub struct JoinedTestSession {
    pub test_session: RawTestSession,
    pub test_session_registration: Option<RawTestSessionRegistration>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct TestSession {
    pub id: u64,
    pub test_id: u64,
    pub name: String,
    pub registrations: Vec<TestSessionRegistration>,
    pub registrations_enabled: bool,
    pub opening_enabled: bool,
    pub submissions_enabled: bool,
}

#[derive(Serialize, Deserialize)]
pub struct NewTestSession {
    pub test_id: u64,
    pub name: String,
}

#[derive(Serialize, Deserialize)]
pub struct TestSessionList {
    pub test_sessions: Vec<TestSession>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct TestSessionRegistration {
    pub id: u64,
    pub taker_id: u64,
    pub registered: DateTime<Local>,
    pub opened_test: Option<DateTime<Local>>,
    pub submitted_test: Option<DateTime<Local>>,
}

pub enum TestSessionRequest {
    GetTestSessions(Option<u64>),
    GetTestSession(u64),
    CreateTestSession(NewTestSession),
    DeleteTestSession(u64),
    Register(u64),
}

impl TestSessionRequest {
    pub fn from_rouille(
        request: &rouille::Request,
    ) -> Result<TestSessionRequest, Error> {
        let mut url_queries =
            form_urlencoded::parse(request.raw_query_string().as_bytes());
        router!(request,
            (GET) (/) => {

                let test_id = url_queries.find_map(|q| {
                    if q.0 == "test_id" {
                        q.1.parse().ok()
                    } else {
                        None
                    }
                });

                Ok(TestSessionRequest::GetTestSessions(test_id))
            },

            (GET) (/{id: u64}) => {
                Ok(TestSessionRequest::GetTestSession(id))
            },

            (POST) (/{id: u64}/register) => {
                Ok(TestSessionRequest::Register(id))
            },

            (POST) (/) => {
                let request_body = request.data().ok_or(Error::new(ErrorKind::Body))?;
                let new_question: NewTestSession = serde_json::from_reader(request_body)?;

                Ok(TestSessionRequest::CreateTestSession(new_question))
            },

            (DELETE) (/{id: u64}) => {
                Ok(TestSessionRequest::DeleteTestSession(id))
            },

            _ => {
                warn!("Could not create a question request for the given rouille request");
                Err(Error::new(ErrorKind::NotFound))
            }
        )
    }
}

pub enum TestSessionResponse {
    OneTestSession(TestSession),
    ManyTestSessions(TestSessionList),
    NoResponse,
}

impl TestSessionResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            TestSessionResponse::OneTestSession(question) => {
                rouille::Response::json(&question)
            }
            TestSessionResponse::ManyTestSessions(questions) => {
                rouille::Response::json(&questions)
            }
            TestSessionResponse::NoResponse => rouille::Response::empty_204(),
        }
    }
}
