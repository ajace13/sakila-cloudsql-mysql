# Prompt

Below are the outputs of DESCRIBE sakila.payment, sakila.rental, and sakila.film

sakila.payment

```
Field    Type    Null    Key    Default    Extra
0    payment_id    smallint unsigned    NO    PRI    NaN    auto_increment
1    customer_id    smallint unsigned    NO    MUL    NaN
2    staff_id    tinyint unsigned    NO    MUL    NaN
3    rental_id    int    YES    MUL    NaN
4    amount    decimal(5,2)    NO        NaN
5    payment_date    datetime    NO        NaN
6    last_update    timestamp    YES        CURRENT_TIMESTAMP    DEFAULT_GENERATED on update CURRENT_TIMESTAMP
```

sakila.rental

```
Field    Type    Null    Key    Default    Extra
0    rental_id    int    NO    PRI    NaN    auto_increment
1    rental_date    datetime    NO    MUL    NaN
2    inventory_id    mediumint unsigned    NO    MUL    NaN
3    customer_id    smallint unsigned    NO    MUL    NaN
4    return_date    datetime    YES        NaN
5    staff_id    tinyint unsigned    NO    MUL    NaN
6    last_update    timestamp    NO        CURRENT_TIMESTAMP    DEFAULT_GENERATED on update CURRENT_TIMESTAMP
```

sakila.film

```
Field    Type    Null    Key    Default    Extra
0    film_id    smallint unsigned    NO    PRI    NaN    auto_increment
1    title    varchar(128)    NO    MUL    NaN
2    description    text    YES        NaN
3    release_year    year    YES        NaN
4    language_id    tinyint unsigned    NO    MUL    NaN
5    original_language_id    tinyint unsigned    YES    MUL    NaN
6    rental_duration    tinyint unsigned    NO        3
7    rental_rate    decimal(4,2)    NO        4.99
8    length    smallint unsigned    YES        NaN
9    replacement_cost    decimal(5,2)    NO        19.99
10    rating    enum('G','PG','PG-13','R','NC-17')    YES        G
11    special_features    set('Trailers','Commentaries','Deleted Scenes'...    YES        NaN
12    last_update    timestamp    NO        CURRENT_TIMESTAMP    DEFAULT_GENERATED on update CURRENT_TIMESTAMP
```

For each of the tables, what are the primary key, every foreign key and the table it points to, which columns allow NULL, and the data type of each money and date column?

# Response

DESCRIBE shows the `Key` column (PRI/MUL) but not which table a foreign key points to. I checked the Sakila schema file on disk (`sakila-db/sakila-schema.sql`).

The primary keys, NULL columns and data types come from your DESCRIBE output. The foreign-key targets come from the `CONSTRAINT ... FOREIGN KEY` lines in `sakila-db/sakila-schema.sql`, because DESCRIBE only marks those columns `MUL`.

## payment
- **Primary key:** `payment_id` (smallint unsigned, auto_increment)
- **Foreign keys:**
  - `customer_id` → `customer.customer_id`
  - `staff_id` → `staff.staff_id`
  - `rental_id` → `rental.rental_id` (ON DELETE SET NULL)
- **Allows NULL:**
  - `rental_id`
  - `last_update`. DESCRIBE shows it as nullable, but it defaults to CURRENT_TIMESTAMP.
- **Money column:** `amount` is `decimal(5,2)`, NOT NULL.
- **Date columns:**
  - `payment_date` is `datetime`, NOT NULL.
  - `last_update` is `timestamp`.

## rental
- **Primary key:** `rental_id` (int, auto_increment)
- **Foreign keys:**
  - `inventory_id` → `inventory.inventory_id`
  - `customer_id` → `customer.customer_id`
  - `staff_id` → `staff.staff_id`
- **Allows NULL:** `return_date`. A NULL means the rental hasn't been returned yet.
- **Money columns:** none.
- **Date columns:**
  - `rental_date` is `datetime`, NOT NULL.
  - `return_date` is `datetime`, nullable.
  - `last_update` is `timestamp`, NOT NULL.

## film
- **Primary key:** `film_id` (smallint unsigned, auto_increment)
- **Foreign keys:**
  - `language_id` → `language.language_id`
  - `original_language_id` → `language.language_id`. This is a second foreign key to the same table, and it is nullable.
- **Allows NULL:**
  - `description`
  - `release_year`
  - `original_language_id`
  - `length`
  - `rating`
  - `special_features`
- **Money columns:**
  - `rental_rate` is `decimal(4,2)`, NOT NULL, default 4.99.
  - `replacement_cost` is `decimal(5,2)`, NOT NULL, default 19.99.
- **Date columns:**
  - `release_year` is `year`, nullable.
  - `last_update` is `timestamp`, NOT NULL.

## Things to watch
- **Type mismatch:** `payment.rental_id` is `int`, but `payment.customer_id` is `smallint unsigned`. This is how the schema is defined, and it doesn't cause any problem.
- **Join to film:** `film` has no direct link to `payment` or `rental`. The path is `rental` → `inventory` (via `inventory_id`) → `film` (via `film_id`). `inventory` wasn't in your DESCRIBE output, so I haven't shown its columns here.
- **Joins and NULLs:** `payment.rental_id` can be NULL, so an inner join from `payment` to `rental` drops any such rows. In `rental`, only `return_date` can be NULL. For rental duration, filter out NULL return dates or use a LEFT JOIN.
- **Decimal types:** `amount` is DECIMAL, so SUM stays exact. That's why `ROUND(SUM(amount),2)` should match the verified 67406.56.

---

# Prompt 2

Now a new task. I would like you to give me for every row of the plan: tje table, the access type (ALL, index, range, ref, eq_ref, const), the key used and the estimated rows - adn which table is read in full, and why. To do that for each of the explains for our past queries and put the otuput in respones.md

Q4 EXPLAIN

```sql
EXPLAIN
SELECT title, rental_duration
FROM sakila.film
WHERE title LIKE '%ZOO%'
  AND rental_duration >= 4;
```

```
| id | select_type | table | partitions | type | possible_keys | key  | key_len | ref  | rows | filtered | Extra       |
|----|-------------|-------|------------|------|---------------|------|---------|------|------|----------|-------------|
| 1  | SIMPLE      | film  | NULL       | ALL  | NULL          | NULL | NULL    | NULL | 1000 | 3.7      | Using where |
```

Q17 EXPLAIN

```sql
EXPLAIN
SELECT rating, COUNT(*)
FROM sakila.film
WHERE rating IN ('G', 'NC-17', 'PG-13', 'PG', 'R')
GROUP BY rating;
```

```
| id | select_type | table | partitions | type | possible_keys | key  | key_len | ref  | rows | filtered | Extra                        |
|----|-------------|-------|------------|------|---------------|------|---------|------|------|----------|------------------------------|
| 1  | SIMPLE      | film  | NULL       | ALL  | NULL          | NULL | NULL    | NULL | 1000 | 50.0     | Using where; Using temporary |
```

Q26 EXPLAIN

```sql
EXPLAIN
SELECT c.customer_id, c.first_name, c.last_name
FROM sakila.customer c
JOIN sakila.rental r ON r.customer_id = c.customer_id
JOIN sakila.inventory i ON i.inventory_id = r.inventory_id
JOIN sakila.film_category fc ON fc.film_id = i.film_id
JOIN sakila.category cat ON cat.category_id = fc.category_id
WHERE cat.name = 'Horror'
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING COUNT(*) > 3;
```

```
| id | select_type | table | partitions | type   | possible_keys                          | key                       | key_len | ref                    | rows | filtered | Extra                        |
|----|-------------|-------|------------|--------|----------------------------------------|---------------------------|---------|------------------------|------|----------|------------------------------|
| 1  | SIMPLE      | cat   | NULL       | ALL    | PRIMARY                                | NULL                      | NULL    | NULL                   | 16   | 10.0     | Using where; Using temporary |
| 1  | SIMPLE      | fc    | NULL       | ref    | PRIMARY,fk_film_category_category      | fk_film_category_category | 1       | sakila.cat.category_id | 62   | 100.0    | Using index                  |
| 1  | SIMPLE      | i     | NULL       | ref    | PRIMARY,idx_fk_film_id                 | idx_fk_film_id            | 2       | sakila.fc.film_id      | 4    | 100.0    | Using index                  |
| 1  | SIMPLE      | r     | NULL       | ref    | idx_fk_inventory_id,idx_fk_customer_id | idx_fk_inventory_id       | 3       | sakila.i.inventory_id  | 3    | 100.0    | NULL                         |
| 1  | SIMPLE      | c     | NULL       | eq_ref | PRIMARY                                | PRIMARY                   | 2       | sakila.r.customer_id   | 1    | 100.0    | NULL                         |
```

# Response 2

The plans are read from the EXPLAIN output you pasted. The reasons come from the `DESCRIBE` output and the schema in `sakila-db/sakila-schema.sql`. EXPLAIN `rows` is the optimizer's estimate, not a real count. For a join, it is the estimated rows per lookup into that table.

## Q4: films with ZOO in the title and rental_duration >= 4

| Row | Table | Access type | Key used | Est. rows |
|-----|-------|-------------|----------|-----------|
| 1 | `film` | `ALL` | none (`possible_keys` is NULL) | 1000 |

- **Read in full:** `film`, all 1000 rows.
- **Why:**
  - `title LIKE '%ZOO%'` starts with a wildcard. A B-tree index on `title` is sorted from the first character, so it can't find rows that merely contain ZOO. That is why `possible_keys` is NULL even though `title` has an index.
  - `rental_duration` has no index at all.
  - With no usable index, MySQL reads every row and applies both conditions as filters (`Using where`).
- **Filtered 3.7%:** the optimizer expects about 37 of the 1000 rows to pass the filters. It is a guess.

## Q17: film count per rating

| Row | Table | Access type | Key used | Est. rows |
|-----|-------|-------------|----------|-----------|
| 1 | `film` | `ALL` | none (`possible_keys` is NULL) | 1000 |

- **Read in full:** `film`, all 1000 rows.
- **Why:**
  - `rating` has no index. The `Key` column was blank in the `DESCRIBE` output.
  - The `IN (...)` list names all five enum values, so it excludes almost nothing.
  - Even an index here would not save much, since nearly every row has to be read anyway.
- **Filtered 50.0%:** this is a default guess for an `IN` list. It is not based on the data.
- **Using temporary:** the rows aren't read in `rating` order, so MySQL builds a temporary table to hold one counter per rating for the `GROUP BY`.

## Q26: customers who rented more than 3 Horror films

| Row | Table | Access type | Key used | Est. rows |
|-----|-------|-------------|----------|-----------|
| 1 | `cat` (`category`) | `ALL` | none (`PRIMARY` was possible but not used) | 16 |
| 2 | `fc` (`film_category`) | `ref` | `fk_film_category_category` | 62 |
| 3 | `i` (`inventory`) | `ref` | `idx_fk_film_id` | 4 |
| 4 | `r` (`rental`) | `ref` | `idx_fk_inventory_id` | 3 |
| 5 | `c` (`customer`) | `eq_ref` | `PRIMARY` | 1 |

The rows are listed in join order. MySQL starts at `cat`, then looks up each next table using values from the previous row.

- **Read in full:** `cat` (`category`), all 16 rows. It is the only full scan in this plan.
- **Why:**
  - The filter is `cat.name = 'Horror'`, and `category.name` has no index. The only index is the `PRIMARY` key on `category_id`, which the query doesn't filter on.
  - The table has only 16 rows, so scanning it is cheap.
  - Filtered 10.0% means the optimizer expects about 1 or 2 matching rows. In reality, Horror is one category.
- **Why `cat` goes first:** it has the most selective filter, so it gives the smallest starting set. Every join after it is an index lookup.
- **Row 2, `fc`:** `ref` on `fk_film_category_category`. `key_len` 1 is a tinyint unsigned (`category_id`). About 62 films are expected per category. `Using index` means the index alone answers the query, with no table row read.
- **Row 3, `i`:** `ref` on `idx_fk_film_id`. `key_len` 2 is a smallint unsigned (`film_id`). About 4 inventory copies are expected per film. It is also `Using index` (covering).
- **Row 4, `r`:** `ref` on `idx_fk_inventory_id`. `key_len` 3 is a mediumint unsigned (`inventory_id`). About 3 rentals are expected per inventory copy. `Extra` is NULL, so MySQL must read the `rental` table row. `idx_fk_customer_id` was also possible, but it isn't the join path being followed here.
- **Row 5, `c`:** `eq_ref` on `PRIMARY` with `key_len` 2 (`customer_id`). Exactly one customer row is expected per rental. This is the best join access type.
- **Using temporary (row 1):** this applies to the whole query. The `GROUP BY` is on customer columns, but the rows arrive in category order, so MySQL uses a temporary table to group them before applying `HAVING COUNT(*) > 3`.
- **Estimated work:** about 1.6 category rows × 62 × 4 × 3 × 1 is roughly 1,200 `rental` lookups. These are index lookups, not a scan of the 16,044 rental rows.

## Summary

| Query | Table read in full | Rows | Why |
|-------|--------------------|------|-----|
| Q4 | `film` | 1000 | A leading-wildcard `LIKE` can't use the `title` index, and `rental_duration` has no index. |
| Q17 | `film` | 1000 | `rating` has no index, and the `IN` list matches nearly every row. |
| Q26 | `category` | 16 | `category.name` has no index, and the table is tiny. |

None of the plans use access type `index` or `range`. Q26 does show `Using index` on `fc` and `i`. That is a different thing: it means a covering index, not a full index scan.
