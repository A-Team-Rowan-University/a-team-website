-- Your SQL goes here
CREATE TABLE permissions (
  id SERIAL PRIMARY KEY,
  permission_name VARCHAR(255) NOT NULL
);

INSERT INTO permissions (permission_name) VALUES
  ("GetUsers"),
  ("CreateUsers"),
  ("UpdateUsers"),
  ("DeleteUsers"),

  ("GetPermission"),
  ("CreatePermission"),
  ("UpdatePermission"),
  ("DeletePermission"),

  ("GetUserPermission"),
  ("CreateUserPermission"),
  ("UpdateUserPermission"),
  ("DeleteUserPermission"),

  ("GetChemical"),
  ("CreateChemical"),
  ("UpdateChemical"),
  ("DeleteChemical"),

  ("GetChemicalInventory"),
  ("CreateChemicalInventory"),
  ("UpdateChemicalInventory"),
  ("DeleteChemicalInventory");

CREATE TABLE user_permissions (
  user_permission_id SERIAL PRIMARY KEY,
  permission_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  FOREIGN KEY (permission_id)
    REFERENCES permissions(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (user_id)
    REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
);
