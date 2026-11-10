-- Five simple facts an AI assistant stated about Sakila, each with the one query that proves or disproves it,
-- then one query the assistant wrote, checked by a second, independent query.

-- Fact 1: 1,000 films, 200 actors, 599 customers
SELECT (SELECT COUNT(*) FROM sakila.film) AS films,
       (SELECT COUNT(*) FROM sakila.actor) AS actors,
       (SELECT COUNT(*) FROM sakila.customer) AS customers;

-- Fact 2: 16,044 rentals and 16,044 payments
SELECT (SELECT COUNT(*) FROM sakila.rental) AS rentals,
       (SELECT COUNT(*) FROM sakila.payment) AS payments;

-- Fact 3: PG-13 is the most common rating (223 films)
SELECT rating, COUNT(*) AS films
FROM sakila.film
GROUP BY rating
ORDER BY films DESC, rating;

-- Fact 4: payments run from 2005-05-24 22:53:30 to 2006-02-14 15:16:03
SELECT MIN(payment_date) AS earliest, MAX(payment_date) AS latest
FROM sakila.payment;

-- Fact 5: 16 categories
SELECT COUNT(*) AS categories FROM sakila.category;

-- Which store has more customers? (query written by the assistant)
SELECT store_id, COUNT(*) AS customers
FROM sakila.customer
GROUP BY store_id
ORDER BY customers DESC;

-- Independent check: a plain COUNT(*) must equal the sum of the per-store counts.
SELECT (SELECT COUNT(*) FROM sakila.customer) AS total_customers,
       SUM(g.customers)                       AS sum_of_store_counts
FROM (SELECT store_id, COUNT(*) AS customers FROM sakila.customer GROUP BY store_id) g;
