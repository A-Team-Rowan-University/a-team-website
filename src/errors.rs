use std::error::Error;
use std::fmt;

use log::error;

use crate::search::SearchParseError;

#[derive(Debug, Copy, Clone)]
pub enum WebdevErrorKind {
    Database,
    Format,
    AccessDenied,
    NotFound,
}

#[derive(Debug)]
pub struct WebdevError {
    kind: WebdevErrorKind,
    source: Option<Box<dyn Error>>,
}

impl std::fmt::Display for WebdevError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self.kind {
            WebdevErrorKind::Database => write!(f, "Database error!"),
            WebdevErrorKind::Format => write!(f, "Format error!"),
            WebdevErrorKind::AccessDenied => write!(f, "Accessed denied!"),
            WebdevErrorKind::NotFound => write!(f, "Not found!"),
        }
    }
}

impl Error for WebdevError {
    fn source(&self) -> Option<&(dyn Error + 'static)> {
        match self.source {
            Some(ref e) => Some(e.as_ref()),
            None => None,
        }
    }
}

impl WebdevError {
    pub fn new(kind: WebdevErrorKind) -> WebdevError {
        WebdevError { kind, source: None }
    }

    pub fn with_source(
        kind: WebdevErrorKind,
        source: Box<dyn Error>,
    ) -> WebdevError {
        WebdevError {
            kind,
            source: Some(source),
        }
    }

    pub fn kind(&self) -> WebdevErrorKind {
        return self.kind;
    }
}

impl From<diesel::result::Error> for WebdevError {
    fn from(d: diesel::result::Error) -> WebdevError {
        WebdevError::with_source(WebdevErrorKind::Database, Box::new(d))
    }
}

impl From<serde_json::Error> for WebdevError {
    fn from(s: serde_json::Error) -> WebdevError {
        WebdevError::with_source(WebdevErrorKind::Format, Box::new(s))
    }
}

impl From<std::num::ParseIntError> for WebdevError {
    fn from(s: std::num::ParseIntError) -> WebdevError {
        WebdevError::with_source(WebdevErrorKind::Format, Box::new(s))
    }
}

impl From<std::str::ParseBoolError> for WebdevError {
    fn from(s: std::str::ParseBoolError) -> WebdevError {
        WebdevError::with_source(WebdevErrorKind::Format, Box::new(s))
    }
}

impl From<url::ParseError> for WebdevError {
    fn from(s: url::ParseError) -> WebdevError {
        WebdevError::with_source(WebdevErrorKind::Format, Box::new(s))
    }
}

impl From<SearchParseError> for WebdevError {
    fn from(s: SearchParseError) -> WebdevError {
        WebdevError::with_source(WebdevErrorKind::Format, Box::new(s))
    }
}

impl From<WebdevError> for rouille::Response {
    fn from(e: WebdevError) -> rouille::Response {

        error!("{:?} -> {:?}", e.kind(), e.source());

        match e.kind() {
            WebdevErrorKind::NotFound => {
                rouille::Response::text(e.to_string()).with_status_code(404)
            }
            WebdevErrorKind::AccessDenied => {
                rouille::Response::text(e.to_string()).with_status_code(401)
            }
            WebdevErrorKind::Format => {
                rouille::Response::text(e.to_string()).with_status_code(400)
            }
            WebdevErrorKind::Database => {
                rouille::Response::text(e.to_string()).with_status_code(500)
            }
        }
    }
}
