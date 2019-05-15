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

