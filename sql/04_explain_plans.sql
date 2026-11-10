-- Query plans for three of the questions in 02_sakila_questions.sql: a single-table filter (Q4), a GROUP BY
-- aggregate (Q17) and a five-table join (Q26). docs/query_plans.md reads each plan row by row.

-- Q4: leading-wildcard LIKE, so the index on title cannot be used (type ALL on film, 1,000 rows).
EXPLAIN
SELECT title, rental_duration
FROM sakila.film
WHERE title LIKE '%ZOO%'
  AND rental_duration >= 4;

-- Q17: rating has no index (type ALL on film; Using temporary for the GROUP BY).
EXPLAIN
SELECT rating, COUNT(*)
FROM sakila.film
WHERE rating IN ('G', 'NC-17', 'PG-13', 'PG', 'R')
GROUP BY rating;

-- Q26: starts from category (16 rows, full scan), then index lookups all the way to customer.
EXPLAIN
SELECT c.customer_id, c.first_name, c.last_name
FROM sakila.customer c
JOIN sakila.rental r         ON r.customer_id   = c.customer_id
JOIN sakila.inventory i      ON i.inventory_id  = r.inventory_id
JOIN sakila.film_category fc ON fc.film_id      = i.film_id
JOIN sakila.category cat     ON cat.category_id = fc.category_id
WHERE cat.name = 'Horror'
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(*) > 3;
