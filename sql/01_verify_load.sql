-- Verify the Sakila load: the same three numbers infra/deploy_sakila.sh prints, plus row counts.
-- Expected for Sakila 1.5 (downloads.mysql.com/docs/sakila-db.tar.gz): 16 base tables, 1,000 films,
-- 16,044 payments totalling 67,406.56. Older published figures quote 16,049 / 67,416.51 from an older release;
-- reconcile against the data you loaded, never against a remembered number.
SELECT
  (SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = 'sakila' AND table_type = 'BASE TABLE') AS base_tables,
  (SELECT COUNT(*) FROM sakila.film)                            AS films,
  (SELECT COUNT(*) FROM sakila.payment)                         AS payments,
  (SELECT ROUND(SUM(amount), 2) FROM sakila.payment)            AS payment_total;

SELECT 'actor' AS table_name, COUNT(*) AS row_count FROM sakila.actor
UNION ALL SELECT 'address', COUNT(*) FROM sakila.address
UNION ALL SELECT 'category', COUNT(*) FROM sakila.category
UNION ALL SELECT 'city', COUNT(*) FROM sakila.city
UNION ALL SELECT 'country', COUNT(*) FROM sakila.country
UNION ALL SELECT 'customer', COUNT(*) FROM sakila.customer
UNION ALL SELECT 'film', COUNT(*) FROM sakila.film
UNION ALL SELECT 'film_actor', COUNT(*) FROM sakila.film_actor
UNION ALL SELECT 'film_category', COUNT(*) FROM sakila.film_category
UNION ALL SELECT 'film_text', COUNT(*) FROM sakila.film_text
UNION ALL SELECT 'inventory', COUNT(*) FROM sakila.inventory
UNION ALL SELECT 'language', COUNT(*) FROM sakila.language
UNION ALL SELECT 'payment', COUNT(*) FROM sakila.payment
UNION ALL SELECT 'rental', COUNT(*) FROM sakila.rental
UNION ALL SELECT 'staff', COUNT(*) FROM sakila.staff
UNION ALL SELECT 'store', COUNT(*) FROM sakila.store;
