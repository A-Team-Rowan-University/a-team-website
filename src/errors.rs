use std::error::Error as StdError;
use std::fmt;

use log::error;

use crate::search::SearchParseError;

#[derive(Debug, Copy, Clone)]
pub enum ErrorKind {
    Database,
    Url,
    Body,
    NotFound,
}

#[derive(Debug)]
pub struct Error {
    kind: ErrorKind,
    source: Option<Box<dyn StdError>>,
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match self.kind {
            ErrorKind::Database => write!(f, "Database error!"),
            ErrorKind::Url => write!(f, "Url parse error!"),
            ErrorKind::Body => write!(f, "Body parse error!"),
            ErrorKind::NotFound => write!(f, "Not found!"),
        }
    }
}

impl StdError for Error {
    fn source(&self) -> Option<&(dyn StdError + 'static)> {
        match self.source {
            Some(ref e) => Some(e.as_ref()),
            None => None,
        }
    }
}

impl Error {
    pub fn new(kind: ErrorKind) -> Error {
        Error { kind, source: None }
    }

    pub fn with_source(kind: ErrorKind, source: Box<dyn StdError>) -> Error {
        Error {
            kind,
            source: Some(source),
        }
    }

    pub fn kind(&self) -> ErrorKind {
        return self.kind;
    }

    pub fn to_string_with_source(&self) -> String {
        if let Some(source) = &self.source {
            format!("{}:\n {}", self, source)
        } else {
            format!("{}", self)
        }
    }
}

impl From<diesel::result::Error> for Error {
    fn from(d: diesel::result::Error) -> Error {
        Error::with_source(ErrorKind::Database, Box::new(d))
    }
}

impl From<serde_json::Error> for Error {
    fn from(s: serde_json::Error) -> Error {
        Error::with_source(ErrorKind::Body, Box::new(s))
    }
}

impl From<std::num::ParseIntError> for Error {
    fn from(s: std::num::ParseIntError) -> Error {
        Error::with_source(ErrorKind::Url, Box::new(s))
    }
}

impl From<std::str::ParseBoolError> for Error {
    fn from(s: std::str::ParseBoolError) -> Error {
        Error::with_source(ErrorKind::Url, Box::new(s))
    }
}

impl From<url::ParseError> for Error {
    fn from(s: url::ParseError) -> Error {
        Error::with_source(ErrorKind::Url, Box::new(s))
    }
}

impl From<SearchParseError> for Error {
    fn from(s: SearchParseError) -> Error {
        Error::with_source(ErrorKind::Url, Box::new(s))
    }
}

impl From<Error> for rouille::Response {
    fn from(e: Error) -> rouille::Response {
        error!("{:?} -> {:?}", e.kind(), e.source());

        match e.kind() {
            ErrorKind::NotFound => {
                rouille::Response::text(e.to_string()).with_status_code(404)
            }
            ErrorKind::Url => {
                rouille::Response::text(e.to_string_with_source())
                    .with_status_code(400)
            }
            ErrorKind::Body => {
                rouille::Response::text(e.to_string_with_source())
                    .with_status_code(400)
            }
            ErrorKind::Database => {
                rouille::Response::text(e.to_string()).with_status_code(500)
            }
        }
    }
}
