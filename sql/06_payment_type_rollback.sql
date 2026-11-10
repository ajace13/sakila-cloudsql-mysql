-- Undo 06_payment_type.sql (used by the tests; also the way back if the change is not wanted).
ALTER TABLE sakila.payment DROP FOREIGN KEY fk_payment_payment_type;
ALTER TABLE sakila.payment DROP INDEX idx_fk_payment_type_id;
ALTER TABLE sakila.payment DROP COLUMN payment_type_id;
DROP TABLE sakila.payment_type;
