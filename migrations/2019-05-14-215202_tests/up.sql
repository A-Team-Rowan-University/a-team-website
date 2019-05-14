-- Your SQL goes here
CREATE TABLE questions (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  correct_answer VARCHAR(255) NOT NULL,
  incorrect_answer_1 VARCHAR(255) NOT NULL,
  incorrect_answer_2 VARCHAR(255) NOT NULL,
  incorrect_answer_3 VARCHAR(255) NOT NULL
);

