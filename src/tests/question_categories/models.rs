use rouille;
use rouille::router;
use serde::Deserialize;
use serde::Serialize;
use serde_json;

use log::warn;

use crate::errors::Error;
use crate::errors::ErrorKind;

use crate::tests::questions::models::NewQuestion;
use crate::tests::questions::models::Question;

use super::schema::question_categories;

#[derive(Queryable, Serialize, Deserialize, Debug)]
pub struct RawQuestionCategory {
    pub id: u64,
    pub title: String,
}

#[derive(Insertable, Serialize, Deserialize, Debug)]
#[table_name = "question_categories"]
pub struct NewRawQuestionCategory {
    pub title: String,
}

#[derive(Queryable, Debug)]
pub struct JoinedQuestionCategory {
    pub question_category: RawQuestionCategory,
    pub question: Option<Question>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct QuestionCategory {
    pub id: u64,
    pub title: String,
    pub questions: Vec<Question>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct NewQuestionCategory {
    pub title: String,
    pub questions: Vec<NewQuestion>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct QuestionCategoryList {
    pub question_categories: Vec<QuestionCategory>,
}

pub enum QuestionCategoryRequest {
    GetQuestionCategories,
    GetQuestionCategory(u64),
    CreateQuestionCategory(NewQuestionCategory),
    DeleteQuestionCategory(u64),
}

impl QuestionCategoryRequest {
    pub fn from_rouille(
        request: &rouille::Request,
    ) -> Result<QuestionCategoryRequest, Error> {
        router!(request,
            (GET) (/) => {
                Ok(QuestionCategoryRequest::GetQuestionCategories)
            },

            (GET) (/{id: u64}) => {
                Ok(QuestionCategoryRequest::GetQuestionCategory(id))
            },

            (POST) (/) => {
                let request_body = request.data().ok_or(Error::new(ErrorKind::Body))?;
                let new_question_category: NewQuestionCategory = serde_json::from_reader(request_body)?;

                Ok(QuestionCategoryRequest::CreateQuestionCategory(new_question_category))
            },

            (DELETE) (/{id: u64}) => {
                Ok(QuestionCategoryRequest::DeleteQuestionCategory(id))
            },

            _ => {
                warn!("Could not create a question_category request for the given rouille request");
                Err(Error::new(ErrorKind::NotFound))
            }
        )
    }
}

pub enum QuestionCategoryResponse {
    OneQuestionCategory(QuestionCategory),
    ManyQuestionCategories(QuestionCategoryList),
    NoResponse,
}

impl QuestionCategoryResponse {
    pub fn to_rouille(self) -> rouille::Response {
        match self {
            QuestionCategoryResponse::OneQuestionCategory(
                question_category,
            ) => rouille::Response::json(&question_category),
            QuestionCategoryResponse::ManyQuestionCategories(
                question_categories,
            ) => rouille::Response::json(&question_categories),
            QuestionCategoryResponse::NoResponse => {
                rouille::Response::empty_204()
            }
        }
    }
}
