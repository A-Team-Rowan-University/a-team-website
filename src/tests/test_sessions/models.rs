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

use crate::tests::questions::models::AnonymousQuestionList;
use crate::tests::questions::models::ResponseQuestionList;

use super::schema::test_session_registrations;
use super::schema::test_sessions;

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
    pub score: Option<f32>,
}

#[derive(Insertable, Debug)]
#[table_name = "test_session_registrations"]
pub struct NewRawTestSessionRegistration {
    pub test_session_id: u64,
    pub taker_id: u64,
    pub registered: NaiveDateTime,
    pub opened_test: Option<NaiveDateTime>,
    pub submitted_test: Option<NaiveDateTime>,
    pub score: Option<f32>,
}

#[derive(Debug, AsChangeset)]
#[table_name = "test_session_registrations"]
pub struct PartialRawTestSessionRegistration {
    pub taker_id: Option<u64>,
    pub registered: Option<NaiveDateTime>,
    pub opened_test: Option<Option<NaiveDateTime>>,
    pub submitted_test: Option<Option<NaiveDateTime>>,
    pub score: Option<Option<f32>>,
}

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

#[derive(AsChangeset, Serialize, Deserialize, Debug)]
#[table_name = "test_sessions"]
pub struct PartialTestSession {
    pub registrations_enabled: Option<bool>,
    pub opening_enabled: Option<bool>,
    pub submissions_enabled: Option<bool>,
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
    pub score: Option<f32>,
}

pub enum TestSessionRequest {
    GetTestSessions(Option<u64>),
    GetTestSession(u64),
    CreateTestSession(NewTestSession),
    UpdateTestSession(u64, PartialTestSession),
    DeleteTestSession(u64),
    Register(u64),
    Open(u64),
    Submit(u64, ResponseQuestionList),
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

            (GET) (/{id: u64}/open) => {
                Ok(TestSessionRequest::Open(id))
            },

            (POST) (/{id: u64}/submit) => {
                let request_body = request.data()
                    .ok_or(Error::new(ErrorKind::Body))?;
                let respose_questions: ResponseQuestionList =
                    serde_json::from_reader(request_body)?;
                Ok(TestSessionRequest::Submit(id, respose_questions))
            },

            (POST) (/) => {
                let request_body = request.data()
                    .ok_or(Error::new(ErrorKind::Body))?;
                let new_question: NewTestSession =
                    serde_json::from_reader(request_body)?;
                Ok(TestSessionRequest::CreateTestSession(new_question))
            },

            (PUT) (/{id: u64}) => {
                let request_body = request.data()
                    .ok_or(Error::new(ErrorKind::Body))?;
                let partial_test_session: PartialTestSession =
                    serde_json::from_reader(request_body)?;
                Ok(TestSessionRequest::UpdateTestSession(id, partial_test_session))
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
    AnonymousQuestions(AnonymousQuestionList),
    NoResponse,
}

impl TestSessionResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            TestSessionResponse::OneTestSession(test_session) => {
                rouille::Response::json(&test_session)
            }
            TestSessionResponse::ManyTestSessions(test_sessions) => {
                rouille::Response::json(&test_sessions)
            }
            TestSessionResponse::AnonymousQuestions(questions) => {
                rouille::Response::json(&questions)
            }
            TestSessionResponse::NoResponse => rouille::Response::empty_204(),
        }
    }
}
