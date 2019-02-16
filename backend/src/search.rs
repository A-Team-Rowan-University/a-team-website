#[derive(Debug, PartialEq)]
pub enum SearchParseError {
    Kind(String),
    Term(String),
}

impl std::fmt::Display for SearchParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        match self {
            SearchParseError::Kind(s) => write!(f, "Invalid search kind: {}", s),
            SearchParseError::Term(s) => write!(f, "Invalid search term: {}", s),
        }
    }
}

impl std::error::Error for SearchParseError {}

/// Search for a field that cannot be null
///
/// Use a `NullableSearch<T>` when a field could be null instead of `Search<Option<T>>`
#[derive(Debug, PartialEq)]
pub enum Search<T> {
    /// Field partially matches
    Partial(T),

    /// Field fully matches
    Exact(T),

    /// Do not search by this field
    NoSearch,
}

impl<T: std::str::FromStr> Search<T> {
    pub fn from_query(query: &str) -> Result<Search<T>, SearchParseError> {
        let mut query_iter = query.split(',');

        let kind = query_iter.next().map(|s| s.trim());
        let term = query_iter.next().map(|s| s.trim());

        match (kind, term) {
            (Some("partial"), Some(s)) => s
                .trim()
                .parse()
                .map(|p| Search::Partial(p))
                .map_err(|_| SearchParseError::Term(s.to_owned())),
            (Some("exact"), Some(s)) => s
                .trim()
                .parse()
                .map(|p| Search::Exact(p))
                .map_err(|_| SearchParseError::Term(s.to_owned())),
            (Some("partial"), None) => Err(SearchParseError::Term("".to_owned())),
            (Some("exact"), None) => Err(SearchParseError::Term("".to_owned())),
            (Some(k), Some(_)) => Err(SearchParseError::Kind(k.to_owned())),
            (Some(k), None) => Err(SearchParseError::Kind(k.to_owned())),
            (None, Some(_)) => Err(SearchParseError::Kind("".to_owned())),
            (None, None) => Err(SearchParseError::Kind("".to_owned())),
        }
    }
}

#[test]
fn parse_search_partial_search_works() {
    let s = Search::from_query(" partial , hello ");
    assert_eq!(s, Ok(Search::Partial("hello".to_owned())));
}

#[test]
fn parse_search_exact_search_works() {
    let s = Search::from_query(" exact, hello ");
    assert_eq!(s, Ok(Search::Exact("hello".to_owned())));
}

#[test]
fn parse_search_invalid_kind_with_term_fails() {
    let s: Result<Search<String>, _> = Search::from_query("hello, bye");
    assert_eq!(s, Err(SearchParseError::Kind("hello".to_owned())));
}

#[test]
fn parse_search_no_kind_with_term_fails() {
    let s: Result<Search<String>, _> = Search::from_query(", bye");
    assert_eq!(s, Err(SearchParseError::Kind("".to_owned())));
}

#[test]
fn parse_search_partial_with_no_term_fails() {
    let s: Result<Search<String>, _> = Search::from_query(" partial");
    assert_eq!(s, Err(SearchParseError::Term("".to_owned())));
}

#[test]
fn parse_search_exact_with_no_term_fails() {
    let s: Result<Search<String>, _> = Search::from_query(" exact");
    assert_eq!(s, Err(SearchParseError::Term("".to_owned())));
}

#[test]
fn parse_search_invalid_with_no_term_fails() {
    let s: Result<Search<String>, _> = Search::from_query("hello");
    assert_eq!(s, Err(SearchParseError::Kind("hello".to_owned())));
}

#[test]
fn parse_search_empty_string_fails() {
    let s: Result<Search<String>, _> = Search::from_query("");
    assert_eq!(s, Err(SearchParseError::Kind("".to_owned())));
}

/// Search fo a field that can be null
///
/// This could be done as a `Search<Option>`, but then the
/// cases for Any and None are not entirely clear.
///
/// For example, this would make some sense:
///
/// `PartialSearch(Some(t))` -> Field is not null and partially matches (`PartialSearch(T)`)
/// `ExactSearch(Some(t))` -> Field is not null and fully matches (`ExactSearch(T)`)
/// `PartialSearch(None)` -> Field is not null (`Some`)
/// `ExactSearch(None)` -> Field is null (`None`)
/// `NoSearch` -> Do not search by this field (`NoSearch`)
///
/// but it is not immediatly clear what the `PartialSearch(None)` and `ExactSearch(None)`
/// correspond to, and could be confusing and subjective. Instead, we use this enum.
///
#[derive(Debug, PartialEq)]
pub enum NullableSearch<T> {
    /// Field is not null and partially matches
    Partial(T),

    /// Field is not null and exactly matches
    Exact(T),

    /// Field is not null
    /// (`Some` matches Rust terminology better than `NonNull` or similar)
    Some,

    /// Field is null
    /// (`None` matches Rust terminology better than `Null` or similar)
    None,

    /// Do not search by this field
    NoSearch,
}

impl<T: std::str::FromStr> NullableSearch<T> {
    pub fn from_query(query: &str) -> Result<NullableSearch<T>, SearchParseError> {
        let mut query_iter = query.split(',');

        let kind = query_iter.next().map(|s| s.trim());
        let term = query_iter.next().map(|s| s.trim());

        match (kind, term) {
            (Some("partial"), Some(s)) => s
                .trim()
                .parse()
                .map(|p| NullableSearch::Partial(p))
                .map_err(|_| SearchParseError::Term(s.to_owned())),
            (Some("exact"), Some(s)) => s
                .trim()
                .parse()
                .map(|p| NullableSearch::Exact(p))
                .map_err(|_| SearchParseError::Term(s.to_owned())),

            (Some("some"), None) => Ok(NullableSearch::Some),
            (Some("none"), None) => Ok(NullableSearch::None),

            (Some("partial"), None) => Err(SearchParseError::Term("".to_owned())),
            (Some("exact"), None) => Err(SearchParseError::Term("".to_owned())),

            (Some("some"), Some(s)) => Err(SearchParseError::Term(s.to_owned())),
            (Some("none"), Some(s)) => Err(SearchParseError::Term(s.to_owned())),

            (Some(k), Some(_)) => Err(SearchParseError::Kind(k.to_owned())),
            (Some(k), None) => Err(SearchParseError::Kind(k.to_owned())),

            (None, Some(_)) => Err(SearchParseError::Kind("".to_owned())),
            (None, None) => Err(SearchParseError::Kind("".to_owned())),
        }
    }
}

#[test]
fn parse_nullable_search_partial_search_works() {
    let s = NullableSearch::from_query(" partial , hello ");
    assert_eq!(s, Ok(NullableSearch::Partial("hello".to_owned())));
}

#[test]
fn parse_nullable_search_exact_search_works() {
    let s = NullableSearch::from_query(" exact, hello ");
    assert_eq!(s, Ok(NullableSearch::Exact("hello".to_owned())));
}

#[test]
fn parse_nullable_search_some_works() {
    let s: Result<NullableSearch<String>, _> = NullableSearch::from_query(" some ");
    assert_eq!(s, Ok(NullableSearch::Some));
}

#[test]
fn parse_nullable_search_none_works() {
    let s: Result<NullableSearch<String>, _> = NullableSearch::from_query(" none ");
    assert_eq!(s, Ok(NullableSearch::None));
}

#[test]
fn parse_nullable_search_some_with_term_fails() {
    let s: Result<NullableSearch<String>, _> = NullableSearch::from_query(" some, hello");
    assert_eq!(s, Err(SearchParseError::Term("hello".to_owned())));
}

#[test]
fn parse_nullable_search_none_with_term_fails() {
    let s: Result<NullableSearch<String>, _> = NullableSearch::from_query(" none, hello");
    assert_eq!(s, Err(SearchParseError::Term("hello".to_owned())));
}

#[test]
fn parse_nullable_search_invalid_kind_with_term_fails() {
    let s: Result<NullableSearch<String>, _> = NullableSearch::from_query("hello, bye");
    assert_eq!(s, Err(SearchParseError::Kind("hello".to_owned())));
}

#[test]
fn parse_nullable_search_no_kind_with_term_fails() {
    let s: Result<NullableSearch<String>, _> = NullableSearch::from_query(", bye");
    assert_eq!(s, Err(SearchParseError::Kind("".to_owned())));
}

#[test]
fn parse_nullable_search_partial_with_no_term_fails() {
    let s: Result<NullableSearch<String>, _> = NullableSearch::from_query(" partial");
    assert_eq!(s, Err(SearchParseError::Term("".to_owned())));
}

#[test]
fn parse_nullable_search_exact_with_no_term_fails() {
    let s: Result<NullableSearch<String>, _> = NullableSearch::from_query(" exact");
    assert_eq!(s, Err(SearchParseError::Term("".to_owned())));
}

#[test]
fn parse_nullable_search_invalid_with_no_term_fails() {
    let s: Result<NullableSearch<String>, _> = NullableSearch::from_query("hello");
    assert_eq!(s, Err(SearchParseError::Kind("hello".to_owned())));
}

#[test]
fn parse_nullable_search_empty_string_fails() {
    let s: Result<NullableSearch<String>, _> = NullableSearch::from_query("");
    assert_eq!(s, Err(SearchParseError::Kind("".to_owned())));
}
