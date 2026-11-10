-- 34 questions about Sakila, one query each. Every table is schema-qualified.
-- Run against MySQL 8.0 with the Sakila sample database loaded (see infra/deploy_sakila.sh).
-- tests/test_questions.py runs every query and checks its result; each block starts with '-- Q<n>:'.

-- Q1: List all the movies (title & description) that are rated PG-13.
SELECT title, description
FROM sakila.film
WHERE rating = 'PG-13';

-- Q2: List all movies that are either PG OR PG-13 using the IN operator.
SELECT title, rating
FROM sakila.film
WHERE rating IN ('PG', 'PG-13');

-- Q3: List all staff members (first name, last name, email) whose password is NULL.
SELECT first_name, last_name, email
FROM sakila.staff
WHERE password IS NULL;

-- Q4: Select all films that have title names like ZOO and rental duration greater than or equal to 4.
SELECT title, rental_duration
FROM sakila.film
WHERE title LIKE '%ZOO%'
  AND rental_duration >= 4;

-- Q5: What is the cost of renting the movie ACADEMY DINOSAUR for 2 weeks? Note: use a column alias and watch for the rental_duration value.
--   rental_rate is the price for rental_duration days, and this film's rental_duration is 6, not 7. Two weeks is 14 days, so the cost is
--   rental_rate * 14 / rental_duration = 0.99 x 14 / 6 = 2.31. (If a partial period had to be billed in full, it would be 3 periods = 2.97.)
SELECT ROUND(rental_rate * 14 / rental_duration, 2) AS cost_for_2_weeks
FROM sakila.film
WHERE title = 'ACADEMY DINOSAUR';

-- Q6: List all unique districts where customers, staff, and stores are located. Note: check for NOT NULL values.
--   UNION (not UNION ALL) removes duplicates across the three sources. No district is NULL, but three customer addresses have a blank district
--   (''), so those are excluded as well.
SELECT a.district
FROM sakila.customer c
JOIN sakila.address a ON a.address_id = c.address_id
WHERE a.district IS NOT NULL AND a.district <> ''
UNION
SELECT a.district
FROM sakila.staff s
JOIN sakila.address a ON a.address_id = s.address_id
WHERE a.district IS NOT NULL AND a.district <> ''
UNION
SELECT a.district
FROM sakila.store st
JOIN sakila.address a ON a.address_id = st.address_id
WHERE a.district IS NOT NULL AND a.district <> ''
ORDER BY district;

-- Q7: List the top 10 newest customers across all stores based on customer_id.
SELECT customer_id, first_name, last_name, store_id
FROM sakila.customer
ORDER BY customer_id DESC
LIMIT 10;

-- Q8: Show the total number of movies.
SELECT COUNT(*)
FROM sakila.film;

-- Q9: What is the minimum payment received and the max payment received across all transactions?
SELECT MIN(amount), MAX(amount)
FROM sakila.payment;

-- Q10: Number of customers who rented movies between 02-2005 and 05-2005 (based on payment_date).
--   The window runs from 2005-02-01 up to, but not including, 2005-06-01, so all of May 2005 is counted. The earliest payment in Sakila is
--   2005-05-24, so every match comes from late May 2005.
SELECT COUNT(DISTINCT customer_id)
FROM sakila.payment
WHERE payment_date >= '2005-02-01'
  AND payment_date <  '2005-06-01';

-- Q11: List all movies where replacement_cost is greater than $15 or rental_duration is between 6 and 10 days.
SELECT title, replacement_cost, rental_duration
FROM sakila.film
WHERE replacement_cost > 15
   OR rental_duration BETWEEN 6 AND 10;

-- Q12: What is the total amount spent by customers on movies in the year 2005?
--   Payments dated February 2006 (182 rows) fall outside 2005 and are excluded.
SELECT SUM(amount)
FROM sakila.payment
WHERE payment_date >= '2005-01-01'
  AND payment_date <  '2006-01-01';

-- Q13: What is the average replacement cost across all movies?
SELECT AVG(replacement_cost)
FROM sakila.film;

-- Q14: What is the standard deviation of rental_rate across all movies?
--   STDDEV_POP is the population standard deviation (the same as MySQL's STDDEV), because the question covers all movies. STDDEV_SAMP would give
--   the sample version.
SELECT STDDEV_POP(rental_rate)
FROM sakila.film;

-- Q15: What is the midrange of rental_duration for all movies? ((MAX + MIN) / 2)
SELECT (MAX(rental_duration) + MIN(rental_duration)) / 2
FROM sakila.film;

-- Q16: Customers sorted by first name and last name in ascending order.
SELECT customer_id, first_name, last_name
FROM sakila.customer
ORDER BY first_name ASC, last_name ASC;

-- Q17: Count of movies that are either G / NC-17 / PG-13 / PG / R, grouped by rating.
SELECT rating, COUNT(*)
FROM sakila.film
WHERE rating IN ('G', 'NC-17', 'PG-13', 'PG', 'R')
GROUP BY rating;

-- Q18: Number of addresses in each district.
SELECT district, COUNT(*)
FROM sakila.address
GROUP BY district
ORDER BY district;

-- Q19: Find the movies where the rental_rate is greater than $1, ordered descending.
SELECT title, rental_rate
FROM sakila.film
WHERE rental_rate > 1
ORDER BY rental_rate DESC;

-- Q20: Top 2 movies rated R with the highest replacement_cost.
--   Ten R-rated films tie at the highest replacement cost (29.99), so title breaks the tie and the two rows are repeatable.
SELECT title, rating, replacement_cost
FROM sakila.film
WHERE rating = 'R'
ORDER BY replacement_cost DESC, title
LIMIT 2;

-- Q21: Find the most frequently occurring (mode) rental_rate across products.
SELECT rental_rate, COUNT(*)
FROM sakila.film
GROUP BY rental_rate
ORDER BY COUNT(*) DESC
LIMIT 1;

-- Q22: Find the 2 longest movies with length greater than 50 minutes that have commentaries as a special feature.
--   Four films with commentaries tie at the longest length (185 minutes), so title breaks the tie and the two rows are repeatable.
SELECT title, length, special_features
FROM sakila.film
WHERE length > 50
  AND special_features LIKE '%Commentaries%'
ORDER BY length DESC, title
LIMIT 2;

-- Q23: List the years that have more than 2 movies released.
SELECT release_year
FROM sakila.film
GROUP BY release_year
HAVING COUNT(*) > 2;

-- Q24: List the actors (first_name, last_name) who acted in more than 25 movies. Note: also show the count of movies per actor.
--   Grouped by actor_id as well as the names, because two different actors share the name SUSAN DAVIS.
SELECT a.first_name, a.last_name, COUNT(fa.film_id)
FROM sakila.actor a
JOIN sakila.film_actor fa ON fa.actor_id = a.actor_id
GROUP BY a.actor_id, a.first_name, a.last_name
HAVING COUNT(fa.film_id) > 25;

-- Q25: List the actors who have worked in German-language movies.
--   The result is empty. German exists in sakila.language, but all 1,000 films have language_id = 1 (English) and original_language_id is NULL
--   for every film, so no actor has worked in a German-language movie in this data.
SELECT DISTINCT a.actor_id, a.first_name, a.last_name
FROM sakila.actor a
JOIN sakila.film_actor fa ON fa.actor_id = a.actor_id
JOIN sakila.film f ON f.film_id = fa.film_id
JOIN sakila.language l ON l.language_id = f.language_id
WHERE l.name = 'German';

-- Q26: List all customers who rented more than 3 horror movies.
--   Counts rentals of Horror films, so renting the same film twice counts twice. Counting distinct films instead (HAVING COUNT(DISTINCT
--   i.film_id) > 3) would drop two customers (34 to 32).
SELECT c.customer_id, c.first_name, c.last_name
FROM sakila.customer c
JOIN sakila.rental r ON r.customer_id = c.customer_id
JOIN sakila.inventory i ON i.inventory_id = r.inventory_id
JOIN sakila.film_category fc ON fc.film_id = i.film_id
JOIN sakila.category cat ON cat.category_id = fc.category_id
WHERE cat.name = 'Horror'
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(*) > 3;

-- Q27: List all customers who rented a movie starring SCARLETT BENING.
SELECT DISTINCT c.customer_id, c.first_name, c.last_name
FROM sakila.customer c
JOIN sakila.rental r ON r.customer_id = c.customer_id
JOIN sakila.inventory i ON i.inventory_id = r.inventory_id
JOIN sakila.film_actor fa ON fa.film_id = i.film_id
JOIN sakila.actor a ON a.actor_id = fa.actor_id
WHERE a.first_name = 'SCARLETT'
  AND a.last_name = 'BENING';

-- Q28: Customers residing at postal code 62703 who rented movies that were Documentaries.
SELECT DISTINCT c.customer_id, c.first_name, c.last_name
FROM sakila.customer c
JOIN sakila.address a ON a.address_id = c.address_id
JOIN sakila.rental r ON r.customer_id = c.customer_id
JOIN sakila.inventory i ON i.inventory_id = r.inventory_id
JOIN sakila.film_category fc ON fc.film_id = i.film_id
JOIN sakila.category cat ON cat.category_id = fc.category_id
WHERE a.postal_code = '62703'
  AND cat.name = 'Documentary';

-- Q29: Find all addresses where address2 is not empty (contains some text), returned sorted.
--   The result is empty. In this data address2 is NULL for 4 addresses and an empty string ('') for the other 599, so none contains text.
--   Testing only IS NOT NULL would wrongly return those 599 blank rows.
SELECT address_id, address, address2, district, city_id, postal_code, phone
FROM sakila.address
WHERE address2 IS NOT NULL
  AND address2 <> ''
ORDER BY address2;

-- Q30: How many films involve a "Crocodile" and a "Shark" based on the film description?
SELECT COUNT(*)
FROM sakila.film
WHERE description LIKE '%Crocodile%'
  AND description LIKE '%Shark%';

-- Q31: List the actors who played in a film involving a "Crocodile" and a "Shark", with the release year, sorted by the actors' last names.
SELECT DISTINCT a.first_name, a.last_name, f.release_year
FROM sakila.actor a
JOIN sakila.film_actor fa ON fa.actor_id = a.actor_id
JOIN sakila.film f ON f.film_id = fa.film_id
WHERE f.description LIKE '%Crocodile%'
  AND f.description LIKE '%Shark%'
ORDER BY a.last_name, a.first_name;

-- Q32: Find all film categories with between 55 and 65 films. Return category name and film count, sorted highest to lowest.
SELECT c.name, COUNT(*)
FROM sakila.category c
JOIN sakila.film_category fc ON fc.category_id = c.category_id
GROUP BY c.category_id, c.name
HAVING COUNT(*) BETWEEN 55 AND 65
ORDER BY COUNT(*) DESC;

-- Q33: In which film categories is the average difference between replacement_cost and rental_rate greater than $17?
SELECT c.name
FROM sakila.category c
JOIN sakila.film_category fc ON fc.category_id = c.category_id
JOIN sakila.film f ON f.film_id = fc.film_id
GROUP BY c.category_id, c.name
HAVING AVG(f.replacement_cost - f.rental_rate) > 17;

-- Q34: Overdue-rentals report: search rental for rows with return_date IS NULL where rental_date is further in the past than the film's rental_duration. Return the film name, customer name, and phone number.
--   All of Sakila's rentals are dated 2005-2006, so measured against today every rental with a NULL return_date is overdue. The customer name is
--   returned as separate first_name and last_name columns.
SELECT f.title, c.first_name, c.last_name, a.phone
FROM sakila.rental r
JOIN sakila.inventory i ON i.inventory_id = r.inventory_id
JOIN sakila.film f ON f.film_id = i.film_id
JOIN sakila.customer c ON c.customer_id = r.customer_id
JOIN sakila.address a ON a.address_id = c.address_id
WHERE r.return_date IS NULL
  AND DATEDIFF(CURRENT_DATE(), r.rental_date) > f.rental_duration;
