-- Your SQL goes here
CREATE TABLE permission (
  id SERIAL PRIMARY KEY,
  permission_name VARCHAR(255) NOT NULL
);

INSERT INTO permission (permission_name) VALUES
  ("GetUsers"),
  ("CreateUsers"),
  ("UpdateUsers"),
  ("DeleteUsers"),

  ("GetPermission"),
  ("CreatePermission"),
  ("UpdatePermission"),
  ("DeletePermission"),

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
  access_id SERIAL PRIMARY KEY,
  permission_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  FOREIGN KEY (permission_name)
    REFERENCES permission(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (user_id)
    REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  access_level VARCHAR(255)
);
