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
    PermissionDenied,
    GoogleSignIn,
    GoogleUserNoEmail,
    GoogleUserNotFound,
    RegisteredTwiceForTest,
    RegistrationClosedForTest,
    OpenedTestNotRegistered,
    OpenedTestTwice,
    OpeningClosedForTest,
    SubmissionsClosedForTest,
    TestNotSubmitted,
    Network,
    LaTeX,
    Font,
    Io,
    Unimplemented,
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
            ErrorKind::PermissionDenied => write!(f, "Permission denied!"),
            ErrorKind::GoogleSignIn => write!(f, "Failed to validate Id Token with Google"),
            ErrorKind::GoogleUserNoEmail => write!(f, "Google did not provide an email"),
            ErrorKind::GoogleUserNotFound => write!(
                f,
                "The email provided by Google did not match any users' emails"
            ),
            ErrorKind::Unimplemented => write!(f, "Method not implemented"),
            ErrorKind::RegisteredTwiceForTest => write!(f, "Registered twice for a test"),
            ErrorKind::RegistrationClosedForTest => {
                write!(f, "The test session is closed for registration")
            }
            ErrorKind::OpenedTestNotRegistered => write!(f, "Opened a test not registerd for"),
            ErrorKind::OpenedTestTwice => write!(f, "Opened a test twice"),
            ErrorKind::OpeningClosedForTest => write!(f, "The test session is closed"),
            ErrorKind::TestNotSubmitted => write!(f, "The test was not submitted"),
            ErrorKind::Network => write!(f, "There was a network problem"),
            ErrorKind::LaTeX => write!(f, "There was an LaTeX problem"),
            ErrorKind::Io => write!(f, "There was an io problem"),
            ErrorKind::Font => write!(f, "There was a font problem"),
            ErrorKind::SubmissionsClosedForTest => {
                write!(f, "The test session is closed for submissions")
            }
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

impl From<r2d2::Error> for Error {
    fn from(e: r2d2::Error) -> Error {
        Error::with_source(ErrorKind::Database, Box::new(e))
    }
}

impl From<tectonic::errors::Error> for Error {
    fn from(e: tectonic::errors::Error) -> Error {
        Error::with_source(ErrorKind::LaTeX, Box::new(e))
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

impl From<std::io::Error> for Error {
    fn from(e: std::io::Error) -> Error {
        Error::with_source(ErrorKind::Io, Box::new(e))
    }
}

impl From<google_signin::Error> for Error {
    fn from(e: google_signin::Error) -> Error {
        Error::with_source(ErrorKind::PermissionDenied, Box::new(e))
    }
}

impl From<reqwest::Error> for Error {
    fn from(e: reqwest::Error) -> Error {
        Error::with_source(ErrorKind::Network, Box::new(e))
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
            ErrorKind::Database => rouille::Response::text(e.to_string()).with_status_code(500),
            ErrorKind::Url => {
                rouille::Response::text(e.to_string_with_source()).with_status_code(400)
            }
            ErrorKind::Body => {
                rouille::Response::text(e.to_string_with_source()).with_status_code(400)
            }
            ErrorKind::NotFound => rouille::Response::text(e.to_string()).with_status_code(404),
            ErrorKind::GoogleSignIn => rouille::Response::text(e.to_string()).with_status_code(401),
            ErrorKind::GoogleUserNoEmail => {
                rouille::Response::text(e.to_string()).with_status_code(401)
            }
            ErrorKind::GoogleUserNotFound => {
                rouille::Response::text(e.to_string()).with_status_code(401)
            }
            ErrorKind::PermissionDenied => {
                rouille::Response::text(e.to_string()).with_status_code(401)
            }
            ErrorKind::RegisteredTwiceForTest => {
                rouille::Response::text(e.to_string()).with_status_code(409)
            }
            ErrorKind::RegistrationClosedForTest => {
                rouille::Response::text(e.to_string()).with_status_code(409)
            }
            ErrorKind::OpenedTestNotRegistered => {
                rouille::Response::text(e.to_string()).with_status_code(409)
            }
            ErrorKind::OpenedTestTwice => {
                rouille::Response::text(e.to_string()).with_status_code(409)
            }
            ErrorKind::OpeningClosedForTest => {
                rouille::Response::text(e.to_string()).with_status_code(409)
            }
            ErrorKind::SubmissionsClosedForTest => {
                rouille::Response::text(e.to_string()).with_status_code(409)
            }
            ErrorKind::TestNotSubmitted => {
                rouille::Response::text(e.to_string()).with_status_code(409)
            }
            ErrorKind::Network => {
                rouille::Response::text(e.to_string()).with_status_code(501)
            }
            ErrorKind::LaTeX => {
                rouille::Response::text(e.to_string()).with_status_code(501)
            }
            ErrorKind::Font => {
                rouille::Response::text(e.to_string()).with_status_code(501)
            }
            ErrorKind::Io => {
                rouille::Response::text(e.to_string()).with_status_code(501)
            }
            ErrorKind::Unimplemented => {
                rouille::Response::text(e.to_string()).with_status_code(501)
            }
        }
    }
}
