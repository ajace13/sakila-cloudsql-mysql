# CLAUDE.md — Sakila on Cloud SQL (MySQL 8.0)

## What this folder is
This repo, cloned in Cloud Shell. It stands up a managed MySQL 8.0 instance on Google Cloud SQL from
Cloud Shell, loads the Sakila sample database (MySQL's DVD-rental schema: 16 base tables + 7 views), and
queries it from bash (gcloud sql connect) and a Jupyter notebook (Cloud SQL Python Connector + pymysql).
Every command I ran is recorded in infra/command_log.sh — read it before proposing anything.

## Facts the agent must not guess
- Configuration lives in env.sh (git-ignored) and is read as environment variables:
  PROJECT_ID, REGION, INSTANCE (and DB=sakila). Never write their values into a file or a prompt.
- MYSQL_ROOT_PW is never stored in env.sh or any file. It is set per session with `read -s` and passed as
  --root-password="$MYSQL_ROOT_PW". Scripts must prompt for it if it is unset, not hard-code it.
- The notebook reads INSTANCE_CONNECTION_NAME and MYSQL_ROOT_PW from the environment.
- Instance: MYSQL_8_0, edition ENTERPRISE, tier db-f1-micro, region us-central1, database `sakila`.
- Data source: https://downloads.mysql.com/docs/sakila-db.tar.gz → sakila-db/sakila-schema.sql, then
  sakila-db/sakila-data.sql (schema first). The download is Sakila v1.5.
- Import method used: `gcloud sql connect "$INSTANCE" --user=root` with `source` of each file. If the schema
  fails on triggers/functions (SUPER privilege + binary logging), set the database flag
  log_bin_trust_function_creators=on and re-import.
- Verified counts (v1.5): 16 base tables · film 1000 · actor 200 · customer 599 · rental 16044 ·
  payment 16044 rows · ROUND(SUM(payment.amount),2) = 67406.56.
- Course material quoted 16,049 payments / 67,416.51, which does not match this download. Do not hard-code either total:
  reconcile against SUM(amount) from the payment table. A mismatch means re-import or explain it from the
  data, never "fix" rows.

## How to work here
- Read this file and infra/command_log.sh before proposing anything. Show the plan, then the diff, before
  writing or running anything.
- Do not run gcloud commands that create or delete resources without asking;
  `gcloud sql instances delete` is always ask-first.
- Do not read, print or echo env.sh or any variable value. Use the variable names only.
- Verification is a count or total from SQL compared with a known number above — not "it ran".
- Keep every script idempotent (safe to re-run) and `set -euo pipefail`.
- I record what was asked, what you produced and what I changed in the AI logs under docs/ (I own them;
  do not edit them).

## Tasks (I run these and review every diff)
1. deploy_sakila.sh from infra/command_log.sh: variables at the top read from env.sh, `set -euo pipefail`,
   idempotent (skip instance and database create when they already exist, say "already exists"), download
   and unpack Sakila if missing, import schema then data, print the three verification results
   (base-table count, film count, ROUND(SUM(amount),2) from payment), and support `deploy_sakila.sh down`
   for teardown (instance delete, with a confirmation prompt). Show the diff before anything runs.
2. Top 5 customers by total payments with the city of their store
   (customer → payment; customer → store → address → city), plus a check query proving the per-customer
   totals summed over all customers equal SUM(amount) over payment. Both run in my notebook.
