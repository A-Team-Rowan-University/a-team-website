use rouille;
use rouille::router;
use serde::Deserialize;
use serde::Serialize;
use serde_json;

use log::warn;

use crate::errors::Error;
use crate::errors::ErrorKind;

use super::schema::questions;

#[derive(Queryable, Serialize, Deserialize)]
pub struct Question {
    pub id: u64,
    pub category_id: u64,
    pub title: String,
    pub correct_answer: String,
    pub incorrect_answer_1: String,
    pub incorrect_answer_2: String,
    pub incorrect_answer_3: String,
}

#[derive(Insertable, Serialize, Deserialize)]
#[table_name = "questions"]
pub struct NewQuestion {
    pub title: String,
    pub category_id: u64,
    pub correct_answer: String,
    pub incorrect_answer_1: String,
    pub incorrect_answer_2: String,
    pub incorrect_answer_3: String,
}

#[derive(Serialize, Deserialize)]
pub struct QuestionList {
    pub questions: Vec<Question>,
}

pub enum QuestionRequest {
    GetQuestions,
    CreateQuestion(NewQuestion),
    DeleteQuestion(u64),
}

impl QuestionRequest {
    pub fn from_rouille(
        request: &rouille::Request,
    ) -> Result<QuestionRequest, Error> {
        router!(request,
            (GET) (/) => {
                Ok(QuestionRequest::GetQuestions)
            },

            (POST) (/) => {
                let request_body = request.data().ok_or(Error::new(ErrorKind::Body))?;
                let new_question: NewQuestion = serde_json::from_reader(request_body)?;

                Ok(QuestionRequest::CreateQuestion(new_question))
            },

            (DELETE) (/{id: u64}) => {
                Ok(QuestionRequest::DeleteQuestion(id))
            },

            _ => {
                warn!("Could not create a question request for the given rouille request");
                Err(Error::new(ErrorKind::NotFound))
            }
        )
    }
}

pub enum QuestionResponse {
    OneQuestion(Question),
    ManyQuestions(QuestionList),
    NoResponse,
}

impl QuestionResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            QuestionResponse::OneQuestion(question) => {
                rouille::Response::json(&question)
            }
            QuestionResponse::ManyQuestions(questions) => {
                rouille::Response::json(&questions)
            }
            QuestionResponse::NoResponse => rouille::Response::empty_204(),
        }
    }
}
