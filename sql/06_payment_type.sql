-- Add a payment_type lookup table with a one-to-many relationship to payment.
--   payment_type (payment_type_id PK, method, description)  1 ──< 0..*  payment (payment_type_id FK, nullable)
--
-- Safe to re-run: the table is created only if missing, and the column, index and foreign key are added only
-- if missing (MySQL 8.0 has no ADD COLUMN IF NOT EXISTS, so each step checks information_schema first).
-- Existing payments get NULL: the source never recorded how anyone paid, so no value is invented.
-- SMALLINT(6) in the original design is written SMALLINT here: MySQL 8.0 ignores integer display widths.

CREATE TABLE IF NOT EXISTS sakila.payment_type (
  payment_type_id SMALLINT          NOT NULL,
  method          VARCHAR(10)       NOT NULL,
  description     VARCHAR(45)       NULL,
  last_update     TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (payment_type_id),
  UNIQUE KEY uq_payment_type_method (method)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

SET @has_col := (SELECT COUNT(*) FROM information_schema.columns
                 WHERE table_schema = 'sakila' AND table_name = 'payment' AND column_name = 'payment_type_id');
SET @ddl := IF(@has_col = 0,
  'ALTER TABLE sakila.payment ADD COLUMN payment_type_id SMALLINT NULL AFTER rental_id',
  'DO 0');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_idx := (SELECT COUNT(*) FROM information_schema.statistics
                 WHERE table_schema = 'sakila' AND table_name = 'payment' AND index_name = 'idx_fk_payment_type_id');
SET @ddl := IF(@has_idx = 0,
  'ALTER TABLE sakila.payment ADD INDEX idx_fk_payment_type_id (payment_type_id)',
  'DO 0');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_fk := (SELECT COUNT(*) FROM information_schema.table_constraints
                WHERE table_schema = 'sakila' AND table_name = 'payment'
                  AND constraint_name = 'fk_payment_payment_type' AND constraint_type = 'FOREIGN KEY');
SET @ddl := IF(@has_fk = 0,
  'ALTER TABLE sakila.payment ADD CONSTRAINT fk_payment_payment_type FOREIGN KEY (payment_type_id) REFERENCES sakila.payment_type (payment_type_id) ON DELETE RESTRICT ON UPDATE CASCADE',
  'DO 0');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Check: the new relationship exists, and nothing else about payment changed.
SELECT (SELECT COUNT(*) FROM information_schema.referential_constraints
          WHERE constraint_schema = 'sakila' AND constraint_name = 'fk_payment_payment_type'
            AND referenced_table_name = 'payment_type')        AS fk_present,
       (SELECT COUNT(*) FROM sakila.payment)                    AS payments,
       (SELECT ROUND(SUM(amount), 2) FROM sakila.payment)       AS payment_total,
       (SELECT COUNT(*) FROM sakila.payment WHERE payment_type_id IS NOT NULL) AS payments_with_a_type;
