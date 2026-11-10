-- Top 5 customers by total payments, with the city of the store they belong to,
-- and two checks that the numbers can be trusted.
--
-- Join path: customer -> payment for the totals; customer -> store -> address -> city for the store's city.
-- Using the customer's own address would answer a different question (where the customer lives).
-- Payments are aggregated per customer BEFORE joining, so the store joins cannot repeat payment rows.

SELECT c.customer_id, c.first_name, c.last_name, c.store_id,
       ci.city      AS store_city,
       p.payments,
       p.total_paid
FROM (
  SELECT customer_id, COUNT(*) AS payments, ROUND(SUM(amount), 2) AS total_paid
  FROM sakila.payment
  GROUP BY customer_id
) p
JOIN sakila.customer c ON c.customer_id = p.customer_id
JOIN sakila.store s    ON s.store_id    = c.store_id
JOIN sakila.address a  ON a.address_id  = s.address_id
JOIN sakila.city ci    ON ci.city_id    = a.city_id
ORDER BY p.total_paid DESC, c.customer_id
LIMIT 5;

-- Check 1: per-customer totals, summed over EVERY customer (LEFT JOIN keeps customers with no payments
-- as 0), equal the payment table's own total.
SELECT ROUND(SUM(t.total), 2)                              AS sum_of_customer_totals,
       (SELECT ROUND(SUM(amount), 2) FROM sakila.payment)   AS payment_total,
       ROUND(SUM(t.total), 2) = (SELECT ROUND(SUM(amount), 2) FROM sakila.payment) AS totals_match
FROM (
  SELECT c.customer_id, COALESCE(SUM(p.amount), 0) AS total
  FROM sakila.customer c
  LEFT JOIN sakila.payment p ON p.customer_id = c.customer_id
  GROUP BY c.customer_id
) t;

-- Check 2: the same total, but through the store -> address -> city joins used above. If any of those joins
-- dropped or repeated a customer, this would not match. (Check 1 alone does not test those joins.)
SELECT ROUND(SUM(p.total), 2)                              AS total_through_store_city_joins,
       (SELECT ROUND(SUM(amount), 2) FROM sakila.payment)   AS payment_total,
       COUNT(*)                                             AS customers_with_payments
FROM (
  SELECT customer_id, SUM(amount) AS total FROM sakila.payment GROUP BY customer_id
) p
JOIN sakila.customer c ON c.customer_id = p.customer_id
JOIN sakila.store s    ON s.store_id    = c.store_id
JOIN sakila.address a  ON a.address_id  = s.address_id
JOIN sakila.city ci    ON ci.city_id    = a.city_id;
