use std::io::Read;
use std::io::Cursor;

use crate::diesel::NullableExpressionMethods;
use diesel;
use diesel::mysql::MysqlConnection;
use diesel::BoolExpressionMethods;
use diesel::ExpressionMethods;
use diesel::QueryDsl;
use diesel::RunQueryDsl;

use chrono::offset::Local;
use chrono::offset::TimeZone;

use reqwest;
use image::png::PNGDecoder;
use image::ImageDecoder;
use image::ImageBuffer;
use image::GenericImage;
use image::ImageFormat;
use image::ImageOutputFormat;
use image::Rgba;

use rusttype::Font;
use rusttype::Scale;

use rand::seq::SliceRandom;

use log::error;
use log::trace;

use crate::errors::Error;
use crate::errors::ErrorKind;

use crate::permissions::requests::check_to_run;

use crate::tests::test_sessions::models::{
    JoinedTestSession, NewRawTestSession, NewRawTestSessionRegistration, NewTestSession,
    PartialRawTestSessionRegistration, PartialTestSession, RawTestSession,
    RawTestSessionRegistration, TestSession, TestSessionList, TestSessionRegistration,
    TestSessionRequest, TestSessionResponse,
};

use crate::tests::questions::models::AnonymousQuestion;
use crate::tests::questions::models::AnonymousQuestionList;
use crate::tests::questions::models::Question;
use crate::tests::questions::models::ResponseQuestionList;

use crate::tests::question_categories::requests::get_question_category;

use crate::tests::tests::requests::get_test;

use crate::users::requests::get_user;

use crate::tests::test_sessions::schema::test_session_registrations as test_session_registrations_schema;
use crate::tests::test_sessions::schema::test_sessions as test_sessions_schema;

use crate::tests::questions::schema::questions as questions_schema;

static FONT_DATA: &[u8] = include_bytes!("../../FiraSans-Regular.ttf");

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
        TestSessionRequest::Open(test_session_id) => {
            open(test_session_id, requested_user, database_connection)
                .map(|u| TestSessionResponse::AnonymousQuestions(u))
        }
        TestSessionRequest::Submit(test_session_id, respose_questions) => submit(
            test_session_id,
            respose_questions,
            requested_user,
            database_connection,
        )
        .map(|_| TestSessionResponse::NoResponse),
        TestSessionRequest::GetTestSessions(test_id) => {
            check_to_run(requested_user, "GetTestSessions", database_connection)?;
            get_test_sessions(test_id, database_connection)
                .map(|u| TestSessionResponse::ManyTestSessions(u))
        }
        TestSessionRequest::GetTestSession(id) => {
            check_to_run(requested_user, "GetTestSessions", database_connection)?;
            get_test_session(id, database_connection)
                .map(|u| TestSessionResponse::OneTestSession(u))
        }
        TestSessionRequest::Certificate(id) => {
            //check_to_run(requested_user, "GetTestSessions", database_connection)?;
            generate_certificate(id, database_connection)
                .map(|u| TestSessionResponse::Image(u))
        }
        TestSessionRequest::CreateTestSession(test_session) => {
            check_to_run(requested_user, "CreateTestSessions", database_connection)?;
            create_test_session(test_session, database_connection)
                .map(|u| TestSessionResponse::OneTestSession(u))
        }
        TestSessionRequest::UpdateTestSession(id, test_session) => {
            check_to_run(requested_user, "UpdateTestSessions", database_connection)?;
            update_test_session(id, test_session, database_connection)
                .map(|_| TestSessionResponse::NoResponse)
        }
        TestSessionRequest::DeleteTestSession(id) => {
            check_to_run(requested_user, "DeleteTestSessions", database_connection)?;
            delete_test_session(id, database_connection).map(|_| TestSessionResponse::NoResponse)
        }
    }
}


pub(crate) fn generate_certificate(
    registration_id : u64,
    database_connection: &MysqlConnection,
) -> Result<Vec<u8>, Error> {
    let mut registrations = test_session_registrations_schema::table
        .filter(test_session_registrations_schema::id.eq(registration_id))
        .load::<RawTestSessionRegistration>(database_connection)?;

    let registration = match registrations.pop() {
        Some(registration) => registration,
        None => return Err(Error::new(ErrorKind::Database)),
    };

    if let (Some(completion_date), Some(score)) = (registration.submitted_test, registration.score) {
        let user  = get_user(registration.taker_id, database_connection)?;

        trace!("Fetching certificate template");
        let mut certificate_response = reqwest::get("http://frontend/static/safety_certificate_template.png")?;

        trace!("Reading image");
        let mut bytes = Vec::new();
        certificate_response.read_to_end(&mut bytes)?;
        let mut image = image::load_from_memory(&bytes)?;

        let font = Font::from_bytes(FONT_DATA as &[u8])?;
        let scale = Scale::uniform(177.0);

        let glyphs: Vec<_> = font.layout(
            &format!("{} {}", user.first_name, user.last_name),
            scale,
            rusttype::point(3015.0, 3480.0)
        ).chain(font.layout(
            &format!("{:09}", user.banner_id),
            scale,
            rusttype::point(3015.0, 3834.0)
        )).chain(font.layout(
            &format!("{}", user.email),
            scale,
            rusttype::point(3015.0, 4188.0)
        )).chain(font.layout(
            &format!("{}", completion_date.format("%m/%d/%Y  %I:%M%P")),
            scale,
            rusttype::point(3015.0, 4543.0)
        )).chain(font.layout(
            &format!("{:.2}%", score * 100.0),
            scale,
            rusttype::point(3015.0, 5606.0)
        )).collect();

        for glyph in glyphs {
            if let Some(bounding_box) = glyph.pixel_bounding_box() {
                glyph.draw(|x, y, v| {
                    let v = 255 - ((v * 255.0) as u8);
                    image.put_pixel(
                        x + bounding_box.min.x as u32,
                        y + bounding_box.min.y as u32,
                        Rgba([v, v, v, 255])
                    )
                });
            }
        }

        trace!("Writing image");
        let mut outbuf = Cursor::new(Vec::new());
        image.write_to(&mut outbuf, ImageOutputFormat::PNG)?;
        Ok(outbuf.into_inner())
    } else {
        Err(Error::new(ErrorKind::TestNotSubmitted))
    }
}

// Registration Requirements
//
// Registrations are open for this session
// Sumbitted all other registrations for any session for this test
// Not already registered, opened, or taken for this session
// Test session is not full
//

pub(crate) fn register(
    test_session_id: u64,
    requested_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    let test_session = get_test_session(test_session_id, database_connection)?;

    if test_session.registrations_enabled {
        if let Some(user_id) = requested_user {

            let TestSessionList { test_sessions } = get_test_sessions(None, &database_connection)?;

            let test_session = match test_sessions.iter().cloned().find(|s| s.id == test_session_id) {
                Some(test_session) => test_session,
                None => return Err(Error::new(ErrorKind::NotFound)),
            };

            // Only care about sessions with the currect test id
            let test_sessions: Vec<_> = test_sessions.into_iter().filter(|s| s.test_id == test_session.test_id).collect();

            trace!("test sessions: {:#?}", test_sessions);

            // Fail if registrations not enabled
            if !test_session.registrations_enabled {
                trace!("Registration failed because registration is not renabled for test session: {:#?}", test_session);
                return Err(Error::new(ErrorKind::RegistrationClosedForTest));
            }

            // Fail if any registrations on this test session are for this user
            if let Some(registration) = test_session
                .registrations
                .iter()
                .find(|r| r.taker_id == user_id)
            {
                trace!("Registration failed because the user ({:#}) is already registered for this test session with registration: {:#?}", user_id, registration);
                return Err(Error::new(ErrorKind::RegisteredTwiceForTest));
            }

            // Fail if registered for another test session but did not submit
            if let Some(registration) = test_sessions.iter().flat_map(|s| s.registrations.iter()).find(|r| {
                    r.taker_id == user_id && r.opened_test.is_none() && r.submitted_test.is_none()
            }) {
                trace!(
                    "Registration failed because the user ({:#?}) is registered for other sessions for this test with reigstration: {:#?}",
                    user_id,
                    registration,
                );
                return Err(Error::new(ErrorKind::RegisteredTwiceForTest));
            }

            // Fail if the number of registrations is more than the allowed limit
            if  test_session.max_registrations.map(|max_r| max_r <= test_session.registrations.len() as u32).unwrap_or(false) {
                trace!(
                    "Registration failed because the test session is already full. {}/{:?} registrations",
                    test_session.registrations.len(),
                    test_session.max_registrations,
                );

                // TODO Make a new error type for too many registrations
                return Err(Error::new(ErrorKind::RegistrationClosedForTest));
            }

            // We are good now, so add the registration
            let new_raw_test_session_registration = NewRawTestSessionRegistration {
                test_session_id: test_session_id,
                taker_id: user_id,
                registered: Local::now().naive_local(),
                opened_test: None,
                submitted_test: None,
                score: None,
            };

            diesel::insert_into(test_session_registrations_schema::table)
                .values(new_raw_test_session_registration)
                .execute(database_connection)?;

            Ok(())
        } else {
            Err(Error::new(ErrorKind::PermissionDenied))
        }
    } else {
        Err(Error::new(ErrorKind::RegistrationClosedForTest))
    }
}

pub(crate) fn open(
    test_session_id: u64,
    requested_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<AnonymousQuestionList, Error> {
    if let Some(user_id) = requested_user {
        let test_session = get_test_session(test_session_id, database_connection)?;
        if test_session.opening_enabled {
            let existing_open_registrations = test_session_registrations_schema::table
                .filter(
                    test_session_registrations_schema::test_session_id
                        .eq(test_session_id)
                        .and(
                            test_session_registrations_schema::taker_id
                                .eq(user_id)
                                .and(test_session_registrations_schema::submitted_test.is_null()),
                        ),
                )
                .load::<RawTestSessionRegistration>(database_connection)?;

            trace!(
                "Open test registrations for user {}: {:#?}",
                user_id,
                existing_open_registrations
            );

            if existing_open_registrations.len() == 1 {
                let test_session = get_test_session(test_session_id, database_connection)?;

                let test = get_test(test_session.test_id, database_connection)?;

                let mut all_questions = Vec::new();

                for test_question_category in test.questions {
                    let question_category = get_question_category(
                        test_question_category.question_category_id,
                        database_connection,
                    )?;

                    let questions = questions_schema::table
                        .filter(questions_schema::category_id.eq(question_category.id))
                        .load::<Question>(database_connection)?;

                    let mut chosen_questions: Vec<_> = questions
                        .choose_multiple(
                            &mut rand::thread_rng(),
                            test_question_category.number_of_questions as usize,
                        )
                        .into_iter()
                        .map(|q| {
                            let mut answers = [
                                q.correct_answer.clone(),
                                q.incorrect_answer_1.clone(),
                                q.incorrect_answer_2.clone(),
                                q.incorrect_answer_3.clone(),
                            ];

                            answers.shuffle(&mut rand::thread_rng());

                            AnonymousQuestion {
                                id: q.id,
                                title: q.title.clone(),
                                answer_1: answers[0].clone(),
                                answer_2: answers[1].clone(),
                                answer_3: answers[2].clone(),
                                answer_4: answers[3].clone(),
                            }
                        })
                        .collect();

                    all_questions.append(&mut chosen_questions);
                }

                let partial_raw_test_session_registration = PartialRawTestSessionRegistration {
                    taker_id: None,
                    registered: None,
                    opened_test: Some(Some(Local::now().naive_local())),
                    submitted_test: None,
                    score: None,
                };

                diesel::update(test_session_registrations_schema::table)
                    .set(&partial_raw_test_session_registration)
                    .filter(
                        test_session_registrations_schema::taker_id
                            .eq(user_id)
                            .and(
                                test_session_registrations_schema::test_session_id
                                    .eq(test_session_id),
                            )
                            .and(test_session_registrations_schema::opened_test.is_null()),
                    )
                    .execute(database_connection)?;

                Ok(AnonymousQuestionList {
                    questions: all_questions,
                })
            } else {
                Err(Error::new(ErrorKind::OpenedTestTwice))
            }
        } else {
            Err(Error::new(ErrorKind::OpeningClosedForTest))
        }
    } else {
        Err(Error::new(ErrorKind::PermissionDenied))
    }
}

pub(crate) fn submit(
    test_session_id: u64,
    response_questions: ResponseQuestionList,
    requested_user: Option<u64>,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    if let Some(user_id) = requested_user {
        let test_session = get_test_session(test_session_id, database_connection)?;
        if test_session.submissions_enabled {
            let existing_open_registrations = test_session_registrations_schema::table
                .filter(
                    test_session_registrations_schema::test_session_id
                        .eq(test_session_id)
                        .and(
                            test_session_registrations_schema::taker_id
                                .eq(user_id)
                                .and(test_session_registrations_schema::opened_test.is_not_null())
                                .and(test_session_registrations_schema::submitted_test.is_null()),
                        ),
                )
                .load::<RawTestSessionRegistration>(database_connection)?;

            if existing_open_registrations.len() == 1 {
                let n_questions = response_questions.questions.len();

                if n_questions == 0 {
                    return Err(Error::new(ErrorKind::Body));
                }

                let mut n_correct = 0;

                for response_question in response_questions.questions {
                    let mut questions = questions_schema::table
                        .filter(questions_schema::id.eq(response_question.id))
                        .load::<Question>(database_connection)?;

                    if let Some(question) = questions.pop() {
                        if question.correct_answer == response_question.answer {
                            n_correct += 1;
                        }
                    } else {
                        return Err(Error::new(ErrorKind::Database));
                    }
                }

                let score = n_correct as f32 / n_questions as f32;

                trace!("Score: {}", score);

                let partial_raw_test_session_registration = PartialRawTestSessionRegistration {
                    taker_id: None,
                    registered: None,
                    opened_test: None,
                    submitted_test: Some(Some(Local::now().naive_local())),
                    score: Some(Some(score)),
                };

                diesel::update(test_session_registrations_schema::table)
                    .filter(
                        test_session_registrations_schema::taker_id
                            .eq(user_id)
                            .and(
                                test_session_registrations_schema::test_session_id
                                    .eq(test_session_id),
                            )
                            .and(test_session_registrations_schema::opened_test.is_not_null())
                            .and(test_session_registrations_schema::score.is_null()),
                    )
                    .set(&partial_raw_test_session_registration)
                    .execute(database_connection)?;

                Ok(())
            } else {
                Err(Error::new(ErrorKind::OpenedTestTwice))
            }
        } else {
            Err(Error::new(ErrorKind::SubmissionsClosedForTest))
        }
    } else {
        Err(Error::new(ErrorKind::PermissionDenied))
    }
}

pub(crate) fn condense_join(joined: Vec<JoinedTestSession>) -> Result<Vec<TestSession>, Error> {
    let mut condensed: Vec<TestSession> = Vec::new();

    for join in joined {
        let mut registration = if let Some(RawTestSessionRegistration {
            id: test_session_registration_id,
            test_session_id: _,
            taker_id,
            registered,
            opened_test,
            submitted_test,
            score,
        }) = join.test_session_registration
        {
            let registered = match Local.from_local_datetime(&registered).earliest() {
                Some(registered) => registered,
                None => {
                    error!(
                        "Could not create a datetime from the database! {:?}",
                        registered
                    );

                    return Err(Error::new(ErrorKind::Database));
                }
            };

            let opened_test = opened_test
                .map(|t| match Local.from_local_datetime(&t).earliest() {
                    Some(opened) => Ok(opened),
                    None => {
                        error!("Could not create a datatime from the database! {:?}", t);

                        Err(Error::new(ErrorKind::Database))
                    }
                })
                .transpose()?;

            let submitted_test = submitted_test
                .map(|t| match Local.from_local_datetime(&t).earliest() {
                    Some(submitted_test) => Ok(submitted_test),
                    None => {
                        error!("Could not create a datatime from the database! {:?}", t);

                        Err(Error::new(ErrorKind::Database))
                    }
                })
                .transpose()?;

            vec![TestSessionRegistration {
                id: test_session_registration_id,
                taker_id: taker_id,
                registered: registered,
                opened_test: opened_test,
                submitted_test: submitted_test,
                score: score,
            }]
        } else {
            Vec::new()
        };

        if let Some(test_session) = condensed.iter_mut().find(|t| t.id == join.test_session.id) {
            test_session.registrations.append(&mut registration);
        } else {
            let test_session = TestSession {
                id: join.test_session.id,
                test_id: join.test_session.test_id,
                name: join.test_session.name,
                max_registrations: join.test_session.max_registrations,
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

pub(crate) fn get_test_sessions(
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
                test_sessions_schema::max_registrations,
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
                test_session_registrations_schema::score,
            )
                .nullable(),
        ))
        .into_boxed();

    if let Some(test_id) = test_id {
        query = query.filter(test_sessions_schema::test_id.eq(test_id));
    };

    let joined_test_sessions = query.load::<JoinedTestSession>(database_connection)?;

    trace!("Joined Test Sessions: {:#?}", joined_test_sessions);

    let test_sessions = condense_join(joined_test_sessions)?;

    Ok(TestSessionList {
        test_sessions: test_sessions,
    })
}

pub(crate) fn get_test_session(
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
                test_sessions_schema::max_registrations,
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
                test_session_registrations_schema::score,
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

pub(crate) fn create_test_session(
    test_session: NewTestSession,
    database_connection: &MysqlConnection,
) -> Result<TestSession, Error> {
    let new_raw_test_session = NewRawTestSession {
        test_id: test_session.test_id,
        name: test_session.name,
        max_registrations: test_session.max_registrations,
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
            max_registrations: inserted_test_session.max_registrations,
            registrations: Vec::new(),
            registrations_enabled: inserted_test_session.registrations_enabled,
            opening_enabled: inserted_test_session.opening_enabled,
            submissions_enabled: inserted_test_session.submissions_enabled,
        })
    } else {
        Err(Error::new(ErrorKind::Database))
    }
}

pub(crate) fn update_test_session(
    id: u64,
    test_session: PartialTestSession,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::update(test_sessions_schema::table)
        .filter(test_sessions_schema::id.eq(id))
        .set(&test_session)
        .execute(database_connection)?;
    Ok(())
}

pub(crate) fn delete_test_session(
    id: u64,
    database_connection: &MysqlConnection,
) -> Result<(), Error> {
    diesel::delete(test_sessions_schema::table.filter(test_sessions_schema::id.eq(id)))
        .execute(database_connection)?;

    Ok(())
}
