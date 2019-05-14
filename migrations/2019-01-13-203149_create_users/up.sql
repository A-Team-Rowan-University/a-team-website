-- Your SQL goes here
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  banner_id INT(9) UNSIGNED NOT NULL,
  email VARCHAR(255)
);

INSERT INTO users (first_name, last_name, banner_id) VALUES ("root", "root", 0);
UPDATE users
SET
  id = 0
WHERE
  first_name="root" AND last_name="root" AND banner_id=0 AND id != 0;
