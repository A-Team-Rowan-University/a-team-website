-- Your SQL goes here
CREATE TABLE access (
  id SERIAL PRIMARY KEY,
  access_name VARCHAR(255) NOT NULL
);

INSERT INTO access (access_name) VALUES
  ("SearchUser"),
  ("GetUser"),
  ("CreateUser"),
  ("UpdateUser"),
  ("DeleteUser");

CREATE TABLE user_access (
  permission_id SERIAL PRIMARY KEY,
  access_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  FOREIGN KEY (access_id)
    REFERENCES access(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (user_id)
    REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  permission_level VARCHAR(255)
);
