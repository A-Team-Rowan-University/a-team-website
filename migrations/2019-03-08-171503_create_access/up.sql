-- Your SQL goes here
CREATE TABLE access (
  id SERIAL PRIMARY KEY,
  access_name VARCHAR(255) NOT NULL
);

INSERT INTO access (access_name) VALUES
  ("RootAccess"),

  ("GetUsers"),
  ("CreateUsers"),
  ("UpdateUsers"),
  ("DeleteUsers"),

  ("GetAccess"),
  ("CreateAccess"),
  ("UpdateAccess"),
  ("DeleteAccess"),

  ("GetUserAccess"),
  ("CreateUserAccess"),
  ("UpdateUserAccess"),
  ("DeleteUserAccess"),

  ("GetChemical"),
  ("CreateChemical"),
  ("UpdateChemical"),
  ("DeleteChemical"),

  ("GetChemicalInventory"),
  ("CreateChemicalInventory"),
  ("UpdateChemicalInventory"),
  ("DeleteChemicalInventory");

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

INSERT INTO user_access(access_id, user_id, permission_level)
    SELECT (select access.id as access_id from access where access.name = "RootAccess"),
           (select users.id as user_id from users where user.id = 0),
           (select "RootAccess" as permission_level);
