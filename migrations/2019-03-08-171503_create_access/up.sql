-- Your SQL goes here
CREATE TABLE access (
  id SERIAL PRIMARY KEY,
  access_name VARCHAR(255) NOT NULL
);

INSERT INTO access (access_name) VALUES
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
