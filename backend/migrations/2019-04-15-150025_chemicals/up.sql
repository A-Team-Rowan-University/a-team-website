-- Your SQL goes here
CREATE TABLE chemical (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  purpose VARCHAR(1024) NOT NULL
)

CREATE TABLE chemical_inventory (
  id SERIAL PRIMARY KEY,
  purchaser_id BIGINT UNSIGNED NOT NULL,
  custodian_id BIGINT UNSIGNED NOT NULL,
  chemical_id BIGINT unsigned NOT NULL,
  FOREIGN KEY (purchaser_id)
    REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (custodian_id)
    REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  FOREIGN KEY (chemical_id)
    REFERENCES chemical(id)
    ON DELETE CASCADE
    ON UPDATE CASCADE
)
