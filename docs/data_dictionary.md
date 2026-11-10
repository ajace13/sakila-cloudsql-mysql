# Sakila Data Dictionary

Source: `sakila-db/sakila-schema.sql` (Sakila Sample Database Schema, version 1.5). Everything below comes from that file only. Line numbers refer to it.

The schema has no column or table comments, so each "one row" line is read from the table's name, columns and keys. Where the schema does not settle a meaning, the entry says so.

## Base tables

### actor
`CREATE TABLE actor`, lines 44-51

- **Primary key:** `actor_id`
- **Foreign keys:** none
- **One row:** one actor, with a first and last name.

### address
`CREATE TABLE address`, lines 57-73

- **Primary key:** `address_id`
- **Foreign keys:**
  - `city_id` -> `city.city_id`
- **One row:** one street address (address lines, district, postal code, phone) located in one city.

### category
`CREATE TABLE category`, lines 79-84

- **Primary key:** `category_id`
- **Foreign keys:** none
- **One row:** one named film category.

### city
`CREATE TABLE city`, lines 90-98

- **Primary key:** `city_id`
- **Foreign keys:**
  - `country_id` -> `country.country_id`
- **One row:** one city, belonging to one country.

### country
`CREATE TABLE country`, lines 104-109

- **Primary key:** `country_id`
- **Foreign keys:** none
- **One row:** one country.

### customer
`CREATE TABLE customer`, lines 115-131

- **Primary key:** `customer_id`
- **Foreign keys:**
  - `address_id` -> `address.address_id`
  - `store_id` -> `store.store_id`
- **One row:** one customer, with one address, one store, an `active` flag and a `create_date`.

### film
`CREATE TABLE film`, lines 137-157

- **Primary key:** `film_id`
- **Foreign keys:**
  - `language_id` -> `language.language_id`
  - `original_language_id` -> `language.language_id` (nullable)
- **One row:** one film title with its descriptive attributes (rating, length, special features) and rental terms (`rental_duration`, `rental_rate`, `replacement_cost`).

### film_actor
`CREATE TABLE film_actor`, lines 163-171

- **Primary key:** (`actor_id`, `film_id`), composite
- **Foreign keys:**
  - `actor_id` -> `actor.actor_id`
  - `film_id` -> `film.film_id`
- **One row:** one actor paired with one film; the schema gives the pairing no further attributes (no role or billing column).

### film_category
`CREATE TABLE film_category`, lines 177-184

- **Primary key:** (`film_id`, `category_id`), composite
- **Foreign keys:**
  - `film_id` -> `film.film_id`
  - `category_id` -> `category.category_id`
- **One row:** one film assigned to one category.

### film_text
`CREATE TABLE film_text`, lines 199-205

- **Primary key:** `film_id`
- **Foreign keys:** none declared. `film_id` is kept in step with `film.film_id` by the triggers `ins_film`, `upd_film` and `del_film` (lines 214-234), not by a constraint.
- **One row:** a copy of one film's `film_id`, `title` and `description`, carrying a FULLTEXT index on title and description.

### inventory
`CREATE TABLE inventory`, lines 242-252

- **Primary key:** `inventory_id`
- **Foreign keys:**
  - `store_id` -> `store.store_id`
  - `film_id` -> `film.film_id`
- **One row:** one inventory item of one film held by one store. The comment in `inventory_in_stock` (lines 657-658) calls it an "item"; the schema does not say it is a physical copy.

### language
`CREATE TABLE language`, lines 258-263

- **Primary key:** `language_id`
- **Foreign keys:** none
- **One row:** one named language.

### payment
`CREATE TABLE payment`, lines 269-283

- **Primary key:** `payment_id`
- **Foreign keys:**
  - `rental_id` -> `rental.rental_id` (nullable, `ON DELETE SET NULL`)
  - `customer_id` -> `customer.customer_id`
  - `staff_id` -> `staff.staff_id`
- **One row:** one payment of `amount` on `payment_date` from one customer, recorded against one staff member and optionally linked to one rental.

### rental
`CREATE TABLE rental`, lines 290-306

- **Primary key:** `rental_id`
- **Foreign keys:**
  - `staff_id` -> `staff.staff_id`
  - `inventory_id` -> `inventory.inventory_id`
  - `customer_id` -> `customer.customer_id`
- **One row:** one rental of one inventory item by one customer at `rental_date`, recorded against one staff member, with a `return_date` that stays NULL until the item is returned (per the comment at lines 657-658).

### staff
`CREATE TABLE staff`, lines 312-329

- **Primary key:** `staff_id`
- **Foreign keys:**
  - `store_id` -> `store.store_id`
  - `address_id` -> `address.address_id`
- **One row:** one staff member, with one address, one store, login fields (`username`, `password`) and an `active` flag.

### store
`CREATE TABLE store`, lines 335-345

- **Primary key:** `store_id`
- **Foreign keys:**
  - `manager_staff_id` -> `staff.staff_id`
  - `address_id` -> `address.address_id`
- **One row:** one store, with one manager and one address.

## Five relationships a new analyst must know

### 1. film -> inventory -> rental -> payment

- **Join columns:** `film.film_id = inventory.film_id`, `inventory.inventory_id = rental.inventory_id`, `rental.rental_id = payment.rental_id`
- **Source:** `CREATE TABLE film` (137-157), `CREATE TABLE inventory` (242-252), `CREATE TABLE rental` (290-306), `CREATE TABLE payment` (269-283)

This is the path from a film title to the money collected for it: a film has many inventory items, an item has many rentals, and a rental can have payments. Each step is one-to-many reading left to right, and nothing limits a rental to a single payment because `payment.rental_id` has no unique key. `payment.rental_id` is nullable (and is set to NULL if the rental is deleted), so an inner join along this path leaves out payments with no rental, as well as films with no inventory, items never rented and rentals with no payment.

### 2. customer -> store -> staff

- **Join columns:** `customer.store_id = store.store_id`, then either `store.manager_staff_id = staff.staff_id` or `store.store_id = staff.store_id`
- **Source:** `CREATE TABLE customer` (115-131), `CREATE TABLE store` (335-345), `CREATE TABLE staff` (312-329)

Every customer row points at exactly one store, and a store reaches staff by two different routes that answer different questions. `store.manager_staff_id` gives the store's single manager (the unique key `idx_unique_manager` means a staff member manages at most one store), while `staff.store_id` gives every staff member attached to the store and can return several rows per customer. `store` and `staff` reference each other, so pick the route on purpose rather than joining on whichever column name matches.

### 3. film <-> actor (via film_actor)

- **Join columns:** `film.film_id = film_actor.film_id`, `film_actor.actor_id = actor.actor_id`
- **Source:** `CREATE TABLE film_actor` (163-171), which references `CREATE TABLE film` (137-157) and `CREATE TABLE actor` (44-51)

This is a many-to-many relationship: a film can have many actors and an actor can appear in many films, with `film_actor` holding one row per pairing. The composite primary key (`actor_id`, `film_id`) guarantees a given actor is listed against a given film at most once. Joining film to actor repeats each film's values once for every actor on that film, so `COUNT(DISTINCT film_id)` still counts films correctly, but a sum of a film-level amount needs a method that counts each relevant film's amount only once.

### 4. film <-> category (via film_category)

- **Join columns:** `film.film_id = film_category.film_id`, `film_category.category_id = category.category_id`
- **Source:** `CREATE TABLE film_category` (177-184), which references `CREATE TABLE film` (137-157) and `CREATE TABLE category` (79-84)

`film_category` links films to categories, and its primary key is the pair (`film_id`, `category_id`), so the schema permits a film to sit in more than one category but does not establish that any film actually does. The file's comment on the `sales_by_film_category` view (lines 423-424) says some titles belong to more than one category and that totals therefore exceed 100%, but that is a claim about the data, which this file does not contain. Per-category totals may therefore overlap, and determining whether they do requires checking the data for any `film_id` with more than one row in `film_category`.

### 5. address -> city -> country

- **Join columns:** `address.city_id = city.city_id`, `city.country_id = country.country_id`
- **Source:** `CREATE TABLE address` (57-73), `CREATE TABLE city` (90-98), `CREATE TABLE country` (104-109)

Geography is a strict hierarchy: each address is in exactly one city and each city is in exactly one country. Both foreign key columns are `NOT NULL`, so inner joins up the chain lose no address rows. Customers, staff and stores all reach this chain through their own `address_id`, and `address.district` is a plain text column with no lookup table.

## Not stated in the schema

These are things an analyst might assume but the SQL file does not say.

- **What `customer.store_id` means.** The schema only says a customer references one store. It does not say whether that is a home store, the store where they signed up, or something else.
- **What `staff_id` means on `rental` and `payment`.** The foreign keys say a staff member is attached to each row. That they processed the transaction is an inference.
- **Consistency across paths.** No constraint makes `payment.customer_id` match the customer on the linked rental, or makes the staff member on a rental belong to the store that holds the inventory item, or makes a customer rent only from their own store.
- **Currency of money columns.** `payment.amount`, `film.rental_rate` and `film.replacement_cost` are decimals with no currency given.
- **Units.** `film.length` and `film.rental_duration` have no units in their definitions. The comments in `get_customer_balance` (lines 551-556) treat `rental_duration` as days; `length` is never explained.
- **Time zones.** No `DATETIME` or `TIMESTAMP` column states a time zone.
- **`address.location`.** This column exists only on MySQL 5.7.5 and higher (line 67, version-conditional comment). The schema does not say what it holds beyond its `GEOMETRY` type.
- **Actual cardinalities.** This file defines structure only and holds no data, so whether any film really has two categories, or any rental really has two payments, cannot be confirmed from it.
