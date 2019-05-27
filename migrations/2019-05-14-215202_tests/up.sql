-- Your SQL goes here
CREATE TABLE question_categories (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL
);

CREATE TABLE questions (
  id SERIAL PRIMARY KEY,
  category_id BIGINT UNSIGNED NOT NULL,
  title VARCHAR(255) NOT NULL,
  correct_answer VARCHAR(255) NOT NULL,
  incorrect_answer_1 VARCHAR(255) NOT NULL,
  incorrect_answer_2 VARCHAR(255) NOT NULL,
  incorrect_answer_3 VARCHAR(255) NOT NULL,
  FOREIGN KEY (category_id)
    REFERENCES question_categories(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE TABLE tests (
  id SERIAL PRIMARY KEY,
  creator_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(255) NOT NULL,
  FOREIGN KEY (creator_id)
    REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);

CREATE TABLE test_question_categories (
    test_id BIGINT UNSIGNED NOT NULL,
    question_category_id BIGINT UNSIGNED NOT NULL,
    number_of_questions INT UNSIGNED NOT NULL,
    PRIMARY KEY (test_id, question_category_id),
    FOREIGN KEY (test_id)
      REFERENCES tests(id)
      ON DELETE CASCADE
      ON UPDATE CASCADE,
    FOREIGN KEY (question_category_id)
      REFERENCES question_categories(id)
      ON DELETE CASCADE
      ON UPDATE CASCADE
);

CREATE TABLE test_sessions (
    id SERIAL PRIMARY KEY,
    test_id BIGINT UNSIGNED NOT NULL,
    name VARCHAR(255) NOT NULL,
    registrations_enabled TINYINT NOT NULL,
    opening_enabled TINYINT NOT NULL,
    submissions_enabled TINYINT NOT NULL,
    FOREIGN KEY (test_id)
      REFERENCES tests(id)
      ON DELETE CASCADE
      ON UPDATE CASCADE
);

CREATE TABLE test_session_registrations (
    id SERIAL PRIMARY KEY,
    test_session_id BIGINT UNSIGNED NOT NULL,
    taker_id BIGINT UNSIGNED NOT NULL,
    registered TIMESTAMP NOT NULL,
    opened_test TIMESTAMP,
    submitted_test TIMESTAMP,
    score FLOAT,
    FOREIGN KEY (test_session_id)
      REFERENCES test_sessions(id)
      ON DELETE CASCADE
      ON UPDATE CASCADE,
    FOREIGN KEY (taker_id)
      REFERENCES users(id)
      ON DELETE CASCADE
      ON UPDATE CASCADE
);

INSERT INTO access (access_name) VALUES
  ("GetQuestions"),
  ("CreateQuestions"),
  ("UpdateQuestions"),
  ("DeleteQuestions"),

  ("GetQuestionCategories"),
  ("CreateQuestionCategories"),
  ("UpdateQuestionCategories"),
  ("DeleteQuestionCategories"),

  ("GetTests"),
  ("CreateTests"),
  ("UpdateTests"),
  ("DeleteTests"),

  ("GetTestSessions"),
  ("CreateTestSessions"),
  ("UpdateTestSessions"),
  ("DeleteTestSessions"),

  ("GetTestSessionRegistrations"),
  ("CreateTestSessionRegistrations"),
  ("UpdateTestSessionRegistrations"),
  ("DeleteTestSessionRegistrations");

