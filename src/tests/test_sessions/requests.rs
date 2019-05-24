use crate::diesel::NullableExpressionMethods;
use diesel;
use diesel::mysql::MysqlConnection;
use diesel::BoolExpressionMethods;
use diesel::ExpressionMethods;
use diesel::QueryDsl;
use diesel::RunQueryDsl;

use chrono::offset::Local;
use chrono::offset::TimeZone;

use log::error;
use log::trace;

use crate::errors::Error;
use crate::errors::ErrorKind;

use crate::access::requests::check_to_run;

use crate::tests::test_sessions::models::{
    JoinedTestSession, NewRawTestSession, NewRawTestSessionRegistration,
    NewTestSession, RawTestSession, RawTestSessionRegistration, TestSession,
    TestSessionList, TestSessionRegistration, TestSessionRequest,
    TestSessionResponse,
};

use crate::tests::test_sessions::schema::test_session_registrations as test_session_registrations_schema;
use crate::tests::test_sessions::schema::test_sessions as test_sessions_schema;

pub fn handle_test_session(
    request: TestSessionRequest,
    requested_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<TestSessionResponse, Error> {
    match request {
        TestSessionRequest::Register(test_session_id) => {
            register(test_session_id, requested_user, database_connection)
                .map(|_| TestSessionResponse::NoResponse)
        }
        TestSessionRequest::GetTestSessions(test_id) => {
            check_to_run(
                requested_user,
                "GetTestSessions",
                database_connection,
            )?;
            get_test_sessions(test_id, database_connection)
                .map(|u| TestSessionResponse::ManyTestSessions(u))
        }
        TestSessionRequest::GetTestSession(id) => {
            check_to_run(
                requested_user,
                "GetTestSessions",
                database_connection,
            )?;
            get_test_session(id, database_connection)
                .map(|u| TestSessionResponse::OneTestSession(u))
        }
        TestSessionRequest::CreateTestSession(test_session) => {
            check_to_run(
                requested_user,
                "CreateTestSessions",
                database_connection,
            )?;
            create_test_session(test_session, database_connection)
                .map(|u| TestSessionResponse::OneTestSession(u))
        }
        TestSessionRequest::DeleteTestSession(id) => {
            check_to_run(
                requested_user,
                "DeleteTestSessions",
                database_connection,
            )?;
            delete_test_session(id, database_connection)
                .map(|_| TestSessionResponse::NoResponse)
        }
    }
}

fn register(
    test_session_id: u64,
    requested_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    if let Some(user_id) = requested_user {
        let existing_open_registrations =
            test_session_registrations_schema::table
                .filter(
                    test_session_registrations_schema::taker_id
                        .eq(user_id)
                        .and(
                            test_session_registrations_schema::opened_test
                                .is_null(),
                        )
                        .or(test_session_registrations_schema::submitted_test
                            .is_null()),
                )
                .load::<RawTestSessionRegistration>(database_connection)?;

        if existing_open_registrations.len() == 0 {
            let new_raw_test_session_registration =
                NewRawTestSessionRegistration {
                    test_session_id: test_session_id,
                    taker_id: user_id,
                    registered: Local::now().naive_local(),
                    opened_test: None,
                    submitted_test: None,
                };

            diesel::insert_into(test_session_registrations_schema::table)
                .values(new_raw_test_session_registration)
                .execute(database_connection)?;

            Ok(())
        } else {
            Err(Error::new(ErrorKind::RegisteredTwiceForTest))
        }
    } else {
        Err(Error::new(ErrorKind::AccessDenied))
    }
}

fn condense_join(
    joined: Vec<JoinedTestSession>,
) -> Result<Vec<TestSession>, Error> {
    let mut condensed: Vec<TestSession> = Vec::new();

    for join in joined {
        let mut registration = if let Some(RawTestSessionRegistration {
            id: test_session_registration_id,
            test_session_id: _,
            taker_id,
            registered,
            opened_test,
            submitted_test,
        }) = join.test_session_registration
        {
            let registered = match Local
                .from_local_datetime(&registered)
                .earliest()
            {
                Some(registered) => registered,
                None => {
                    error!(
                        "Could not create a datetime from the database! {:?}",
                        registered
                    );

                    return Err(Error::new(ErrorKind::Database));
                }
            };

            let opened_test = opened_test.map(|t| {
                match Local.from_local_datetime(&t).earliest() {
                    Some(opened) => Ok(opened),
                    None => {
                        error!(
                            "Could not create a datatime from the database! {:?}",
                            t
                        );

                        Err(Error::new(ErrorKind::Database))
                    }
                }
            }).transpose()?;

            let submitted_test = submitted_test.map(|t| {
                match Local.from_local_datetime(&t).earliest() {
                    Some(submitted_test) => Ok(submitted_test),
                    None => {
                        error!(
                            "Could not create a datatime from the database! {:?}",
                            t
                        );

                        Err(Error::new(ErrorKind::Database))
                    }
                }
            }).transpose()?;

            vec![TestSessionRegistration {
                id: test_session_registration_id,
                taker_id: taker_id,
                registered: registered,
                opened_test: opened_test,
                submitted_test: submitted_test,
            }]
        } else {
            Vec::new()
        };

        if let Some(test_session) =
            condensed.iter_mut().find(|t| t.id == join.test_session.id)
        {
            test_session.registrations.append(&mut registration);
        } else {
            let test_session = TestSession {
                id: join.test_session.id,
                test_id: join.test_session.test_id,
                name: join.test_session.name,
                registrations: registration,
                registrations_enabled: join.test_session.registrations_enabled,
                opening_enabled: join.test_session.opening_enabled,
                submissions_enabled: join.test_session.submissions_enabled,
            };

            condensed.push(test_session);
        }
    }
    Ok(condensed)
}

fn get_test_sessions(
    test_id: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<TestSessionList, Error> {
    let mut query = test_sessions_schema::table
        .left_join(test_session_registrations_schema::table)
        .select((
            (
                test_sessions_schema::id,
                test_sessions_schema::test_id,
                test_sessions_schema::name,
                test_sessions_schema::registrations_enabled,
                test_sessions_schema::opening_enabled,
                test_sessions_schema::submissions_enabled,
            ),
            (
                test_session_registrations_schema::id,
                test_session_registrations_schema::test_session_id,
                test_session_registrations_schema::taker_id,
                test_session_registrations_schema::registered,
                test_session_registrations_schema::opened_test,
                test_session_registrations_schema::submitted_test,
            )
                .nullable(),
        ))
        .into_boxed();

    if let Some(test_id) = test_id {
        query = query.filter(test_sessions_schema::test_id.eq(test_id));
    };

    let joined_test_sessions =
        query.load::<JoinedTestSession>(database_connection)?;

    trace!("Joined Test Sessions: {:#?}", joined_test_sessions);

    let test_sessions = condense_join(joined_test_sessions)?;

    Ok(TestSessionList {
        test_sessions: test_sessions,
    })
}

fn get_test_session(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<TestSession, Error> {
    let joined_test_sessions = test_sessions_schema::table
        .left_join(test_session_registrations_schema::table)
        .select((
            (
                test_sessions_schema::id,
                test_sessions_schema::test_id,
                test_sessions_schema::name,
                test_sessions_schema::registrations_enabled,
                test_sessions_schema::opening_enabled,
                test_sessions_schema::submissions_enabled,
            ),
            (
                test_session_registrations_schema::id,
                test_session_registrations_schema::test_session_id,
                test_session_registrations_schema::taker_id,
                test_session_registrations_schema::registered,
                test_session_registrations_schema::opened_test,
                test_session_registrations_schema::submitted_test,
            )
                .nullable(),
        ))
        .filter(test_sessions_schema::id.eq(id))
        .load::<JoinedTestSession>(database_connection)?;

    trace!("Joined Test Sessions: {:#?}", joined_test_sessions);

    let mut test_sessions = condense_join(joined_test_sessions)?;

    if let Some(test_session) = test_sessions.pop() {
        Ok(test_session)
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

fn create_test_session(
    test_session: NewTestSession,
    database_connection: &MysqlConnection,
) -> Result<TestSession, Error> {
    let new_raw_test_session = NewRawTestSession {
        test_id: test_session.test_id,
        name: test_session.name,
        registrations_enabled: false,
        opening_enabled: false,
        submissions_enabled: false,
    };

    diesel::insert_into(test_sessions_schema::table)
        .values(new_raw_test_session)
        .execute(database_connection)?;

    let mut inserted_test_sessions = test_sessions_schema::table
        .filter(diesel::dsl::sql("id = LAST_INSERT_ID()"))
        .load::<RawTestSession>(database_connection)?;

    if let Some(inserted_test_session) = inserted_test_sessions.pop() {
        Ok(TestSession {
            id: inserted_test_session.id,
            test_id: inserted_test_session.test_id,
            name: inserted_test_session.name,
            registrations: Vec::new(),
            registrations_enabled: inserted_test_session.registrations_enabled,
            opening_enabled: inserted_test_session.opening_enabled,
            submissions_enabled: inserted_test_session.submissions_enabled,
        })
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

fn delete_test_session(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::delete(
        test_sessions_schema::table.filter(test_sessions_schema::id.eq(id)),
    )
    .execute(database_connection)?;

    Ok(())
}
