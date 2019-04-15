-- Your SQL goes here
CREATE TABLE chemical (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  purpose VARCHAR(1023) NOT NULL,
  company_name VARCHAR(255) NOT NULL,
  ingredients VARCHAR(1023) NOT NULL,
  manual_link VARCHAR(1023) NOT NULL
)

CREATE TABLE chemical_inventory (
  id SERIAL PRIMARY KEY,
  purchaser_id BIGINT UNSIGNED NOT NULL,
  custodian_id BIGINT UNSIGNED NOT NULL,
  chemical_id BIGINT UNSIGNED NOT NULL,
  storage_location VARCHAR(255) NOT NULL,
  amount VARCHAR(255) NOT NULL,
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
