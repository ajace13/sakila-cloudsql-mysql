# AI log: deploy script, data dictionary and a two-part query

## 1. Claude Code: deploy_sakila.sh
**Prompt:** Read CLAUDE.md and infra/command_log.sh. Then write deploy_sakila.sh that:
- reads its variables from env.sh at the top (PROJECT_ID, REGION, INSTANCE, DB); don't print their values
- uses set -euo pipefail
- is idempotent: if the instance or the sakila database already exists, say "already exists" and skip creating it
- prompts for MYSQL_ROOT_PW with read -s if it isn't set; never writes a password into the file
- downloads and unpacks Sakila if it isn't already here, then imports sakila-schema.sql followed by sakila-data.sql
- prints the three verification results: base-table count, film count, ROUND(SUM(amount),2) from payment
- supports "./infra/deploy_sakila.sh down" to delete the instance, with a confirmation prompt
Show me the plan and the full diff first. Do not write the file or run anything until I approve.

**What came back:**
Claude proposed a deployment script that loaded configuration from env.sh, checked whether the instance and database existed, downloaded and imported Sakila, printed verification results, and supported teardown with confirmation. It showed the plan and diff before creating the file.

I reviewed the three required items:
- No actual password was hard-coded in the script.
- `set -euo pipefail` was present.
- The existing-instance branch skipped creation and printed “Instance already exists; skipping create.”

**What was wrong:**
- The initial pasted diff contained a duplicated verification/import block and an unmatched `fi`.
- It treated sixteen tables as proof of a complete import and would reimport the destructive schema script for any other table count.
- Failed cloud lookups could be mistaken for missing resources. A later revision also needed an explicit check to stop if schema inspection failed.
- The initial password approach relied on an uncertain MYSQL_PWD fallback. Running through the agent also did not provide a usable password-entry prompt.
- env.sh was missing DB, so the script initially stopped before deployment.
- A verification error suggested missing data even though the actual failure was authentication.
- Claude later quoted a payment total of 67,406.56, whereas older published figures quote 67,416.51. These conflicting expected values need to be reconciled against the actual query output.

**What I changed:**
I requested revisions before approving execution. I had Claude separate import from read-only verification, import only into a confirmed empty schema, stop on failed lookups, remove the global password exports, and require DB to equal sakila.
I also required the schema count to be captured separately with an explicit failure check. I approved adding `export DB=sakila` to env.sh without displaying its contents.
After reviewing the changes, I approved file creation and the syntax check. `bash -n deploy_sakila.sh` passed. Execution confirmed that the existing instance and database skipped creation and that the populated schema skipped import.
I then ran the script in a normal terminal so I could enter the password directly at both prompts. The final run worked. I did not run teardown.

## 2. Claude Cowork: data dictionary
**Prompt:** Moving on to our next task. First read CLAUDE.md, then read sakila-db/sakila-schema.sql. Write docs/data_dictionary.md in this folder:

1. One section per base table (all 16; skip the views). For each: its primary key, its foreign keys (column -> referenced table.column), and one line on what a single row means.
2. Then the five relationships a new analyst must know, each explained in 2–3 sentences with the join columns:
   - film -> inventory -> rental -> payment
   - customer -> store -> staff
   - film <-> actor (via film_actor)
   - film <-> category (via film_category)
   - address -> city -> country

Each must cite the CREATE TABLE statement(s) it comes from. Use only what is in the SQL file. If something isn't stated in the schema, say so rather than guessing.

**What came back:**
Claude produced docs/data_dictionary.md with sections for all 16 base tables, including primary keys, foreign keys, and descriptions of what each row represents. It explained the five requested relationships with join columns and CREATE TABLE citations. It also identified information the schema does not establish, such as currency, certain business meanings, and actual relationship counts in the data.

**What was wrong:**
- The film–category explanation was too confident that category totals necessarily overlap. The composite primary key allows multiple categories per film, but does not prove that the loaded data contains such films. Although a SQL comment makes that claim, the table definition alone cannot verify it.
- The film–actor explanation suggested that aggregating film-level measures before joining would prevent double-counting. The join can still repeat those aggregated values for each actor.

**What I changed:**
I asked Claude to qualify the category explanation and correct the aggregation advice. The revised dictionary now distinguishes relationships permitted by the schema from relationships actually present in the data. It also explains that counting distinct films prevents duplicate film counts, while summing film-level amounts requires counting each relevant film's amount only once.

My follow-up prompt was:

“Make two wording corrections in docs/data_dictionary.md:

1. In film–category, distinguish what the schema permits from what the data actually contains. The composite primary key allows multiple categories per film, but does not establish that any film actually has multiple categories. Explain that category totals may overlap; determining whether they do requires checking the data. Keep the SQL comment citation, but qualify its claim.

2. In film–actor, remove the suggestion that aggregating film-level measures before the join automatically prevents double-counting. Explain that the join can repeat each film’s values for every actor. COUNT(DISTINCT film_id) works for counting films, but sums need a method that counts each relevant film’s amount only once.

Keep the remaining content and CREATE TABLE citations.”

**Manual check:**
I used sed to inspect two CREATE TABLE statements and the relevant SQL comment myself:

- **film_category (lines 177–184):** I confirmed `PRIMARY KEY (film_id, category_id)` and both foreign keys. There is no separate uniqueness constraint on film_id, so multiple categories per film are allowed. However, neither this definition nor the comment at lines 423–424 verifies actual overlap in the loaded data. Claude's original conclusion about category totals was too confident.
- **store (lines 335–345):** I confirmed `UNIQUE KEY idx_unique_manager (manager_staff_id)` and the foreign key to `staff.staff_id`. This supports Claude's claim that a staff member can manage at most one store so as it turns out that claim was correct.

## 3. Claude: a two-part query and its check
**Prompt:** New task. Read CLAUDE.md first. Write two MySQL queries for the sakila database and output them in the chat for me to run. Do not run anything against the database; I will run them in my notebook.

1. Top 5 customers by total payments, with the city of their store. Join path: customer -> payment for the totals, and customer -> store -> address -> city for the store's city. Return customer_id, first and last name, store_id, store city, number of payments and total paid (rounded to 2 decimals), largest total first.
2. A check query proving that the per-customer payment totals, summed over all customers, equal the total of all payments: 67,416.51.

For each query, explain the joins in 2–3 sentences and anything that could make the numbers wrong. Show me the queries before writing the file.

**What came back:**
Claude returned two SELECT queries without running them or writing a file.

The first grouped payments by customer, joined each customer's store to its address and city, and returned the five largest payment totals. It included payment counts and used customer_id to break ties consistently.

The second used a LEFT JOIN to calculate totals for all customers, including customers with no payments. It summed those totals and compared them with an independent SUM(amount) from payment, returning totals_match.

**What was wrong:**
- Claude confidently attributed the difference between 67,416.51 and 67,406.56 to different Sakila releases. That explanation was not independently verified, so I should not present it as an established fact.
- The check query tests whether customer totals reconcile to the payment table. It does not directly test equality to the quoted 67,416.51.
- The check excludes the store, address and city joins, so it does not independently validate that those joins preserve payment totals.

**What I changed:**
No SQL changes were necessary on initial review. I retained the proposed join paths and flagged the explanation of the expected total for correction. I will report the actual notebook results and any difference from the quoted total, rather than assume a release difference explains it.

**My explanation of the joins:**
The first query connects customers to their payments using customer_id, then groups those payment rows to calculate each customer's count and total. To find the store's city, it follows the customer's store_id to store, then the store's address_id to address and its city_id to city; using the customer's own address would answer a different question.

The check query includes every customer with a LEFT JOIN, treating customers without payments as having a zero total. It adds all customer totals and compares that amount with the sum directly from payment.

**Execution and results:**
Everything worked in the notebook. 