-- Your SQL goes here
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  banner_id INT(9) UNSIGNED NOT NULL,
  email VARCHAR(255) NOT NULL
);
