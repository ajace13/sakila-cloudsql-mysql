# Sakila on Cloud SQL — Runbook


> **With this repo cloned**, `infra/deploy_sakila.sh up` does sections 2 to 4 in one re-runnable command, and `infra/start_jupyter.sh` is the launcher from section 5. Configuration lives in `infra/env.sh` (copy `infra/env.example.sh`). The steps below are the manual version, useful for understanding what the script does.

This runbook covers the full workflow, with everything run in **Cloud Shell**: set up a project folder, create a MySQL 8.0 instance on Cloud SQL, load the Sakila database, verify it, query it from a Jupyter notebook through the Cloud SQL Python Connector, and tear it all down.

> **Rule throughout:** no project IDs, passwords, tokens or IP addresses in any file or prompt. Configuration goes in `infra/env.sh` (git-ignored), and the root password is typed at a hidden `read -s` prompt each session.

---

## Contents

1. [Project folder and configuration](#1-project-folder-and-configuration)
2. [Create the Cloud SQL instance](#2-create-the-cloud-sql-instance)
3. [Download and import Sakila](#3-download-and-import-sakila)
4. [Verify the database](#4-verify-the-database)
5. [Python environment and Jupyter in Cloud Shell](#5-python-environment-and-jupyter-in-cloud-shell)
6. [Connect from the notebook](#6-connect-from-the-notebook)
7. [Starting again in a new session](#7-starting-again-in-a-new-session)
8. [Pause or shut down](#8-pause-or-shut-down)
9. [Troubleshooting](#9-troubleshooting)
10. [Quick reference](#10-quick-reference)

---

## 1. Project folder and configuration

Create a Google Cloud project with billing enabled, open Cloud Shell, then run:

```bash
# Get the code
git clone https://github.com/ajace13/sakila-cloudsql-mysql.git ~/sakila-cloudsql-mysql
cd ~/sakila-cloudsql-mysql

# Non-secret configuration (no password in here; infra/env.sh is git-ignored)
cp infra/env.example.sh infra/env.sh
nano infra/env.sh
```

Contents of `infra/env.sh`:

```bash
export PROJECT_ID=your-project-id     # the lowercase project ID, not the display name
export REGION=us-central1
export INSTANCE=sakila-mysql
export DB=sakila
```

```bash
source infra/env.sh
gcloud config set project "$PROJECT_ID"
gcloud config get-value project        # confirm
```

The repo's `.gitignore` already keeps `env.sh`, the Sakila download and notebook checkpoints out of git.

> The project **name** (for example `My-Sakila-Project`) and the project **ID** (`my-sakila-project`) are different. gcloud needs the lowercase ID.

---

## 2. Create the Cloud SQL instance

```bash
cd ~/sakila-cloudsql-mysql
source infra/env.sh

# Enable the Cloud SQL Admin API (once per project)
gcloud services enable sqladmin.googleapis.com

# Root password: typed at a hidden prompt, never stored in a file
read -s MYSQL_ROOT_PW && export MYSQL_ROOT_PW

# MySQL 8.0, Enterprise edition, smallest tier (~5–10 minutes)
gcloud sql instances create "$INSTANCE" \
  --database-version=MYSQL_8_0 \
  --edition=ENTERPRISE \
  --tier=db-f1-micro \
  --region="$REGION" \
  --root-password="$MYSQL_ROOT_PW"

# Database
gcloud sql databases create "$DB" --instance="$INSTANCE"
gcloud sql databases list --instance="$INSTANCE"
```

> If `databases create` reports *database exists*, it was already created, so carry on.

📸 Screenshot: Console → SQL → the instance overview (running, MySQL 8.0, Enterprise, us-central1).

---

## 3. Download and import Sakila

```bash
cd ~/sakila-cloudsql-mysql

wget https://downloads.mysql.com/docs/sakila-db.tar.gz
tar -xzf sakila-db.tar.gz
ls sakila-db            # sakila-data.sql  sakila-schema.sql  sakila.mwb
```

Import the **schema first, then the data**. `gcloud sql connect` starts the Auth Proxy automatically and prompts for the root password:

```bash
gcloud sql connect "$INSTANCE" --user=root --quiet << EOF
source sakila-db/sakila-schema.sql;
source sakila-db/sakila-data.sql;
SHOW DATABASES;
EOF
```

If the schema import fails with *"You do not have the SUPER privilege and binary logging is enabled"*, set this flag and re-run the import:

```bash
gcloud sql instances patch "$INSTANCE" --database-flags=log_bin_trust_function_creators=on
```

---

## 4. Verify the database

Run these interactively for clean screenshots:

```bash
gcloud sql connect "$INSTANCE" --user=root
```

```sql
USE sakila;
SHOW FULL TABLES WHERE Table_type = 'BASE TABLE';   -- 16 rows
SELECT COUNT(*) FROM film;                          -- 1000
SELECT ROUND(SUM(amount),2) FROM payment;           -- 67406.56 (see note)
SELECT COUNT(*) AS payments FROM payment;           -- 16044
SELECT COUNT(*) AS rentals  FROM rental;            -- 16044
exit
```

| Check | Expected | Notes |
|---|---|---|
| Base tables | 16 | Plus 7 views |
| Films | 1,000 | |
| Actors / customers | 200 / 599 | |
| Payments | 16,044 rows, **67,406.56** | Older published figures quote 16,049 / 67,416.51; this download has 16,044 / 67,406.56 |

> **Version note:** the current download is **Sakila v1.5** (`head -30 sakila-db/sakila-data.sql | grep -i version`). Its payment rows total 67,406.56, so a total of 67,406.56 means the import is complete, not broken.

📸 Screenshot: each query and its result.

---

## 5. Python environment and Jupyter in Cloud Shell

One-time setup:

```bash
python3 -m venv ~/venv-sakila
source ~/venv-sakila/bin/activate
pip install jupyterlab pandas "cloud-sql-python-connector[pymysql]"
```

The launcher is `infra/start_jupyter.sh`. It contains no secrets, because the password is typed at runtime. It reads `infra/env.sh`, looks up the instance connection name, asks for the root password with a hidden prompt, and starts JupyterLab on port 8080.

Run it:

```bash
./infra/start_jupyter.sh
```

Then click **Web Preview → Preview on port 8080** in the Cloud Shell toolbar.

> **Why the extra flags:** Cloud Shell's preview proxy drops Jupyter's login cookie, which gives a blank page and `403 Couldn't authenticate` in the log. The Web Preview URL is already restricted to your signed-in Google account, so Jupyter's own token check can be turned off safely here. The script refuses to start outside Cloud Shell for that reason.

> Run it as `./infra/start_jupyter.sh`, not `source infra/start_jupyter.sh`, so the password stays inside the script's process.

---

## 6. Connect from the notebook

**Cell 1: connect.** Credentials come only from environment variables.

```python
import os
import pandas as pd
from google.cloud.sql.connector import Connector

connector = Connector()
cnx = connector.connect(
    os.environ["INSTANCE_CONNECTION_NAME"],   # project:region:instance
    "pymysql",
    user="root",
    password=os.environ["MYSQL_ROOT_PW"],
    db="sakila",
)
cursor = cnx.cursor()

def run(sql):
    """Run a query and return the rows as a DataFrame."""
    cursor.execute(sql)
    cols = [d[0] for d in cursor.description]
    return pd.DataFrame(cursor.fetchall(), columns=cols)

run("SELECT DATABASE() AS db, VERSION() AS mysql_version")   # sakila | 8.0.x-google
```

**Queries.** Put a markdown cell above each one, explaining it.

```python
run("SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'")

run("SELECT COUNT(*) AS film_count FROM film")

run("SELECT actor_id, first_name, last_name FROM actor WHERE first_name = 'JOHN'")

# Films per category (JOIN + GROUP BY)
run("""
SELECT c.name AS category, COUNT(fc.film_id) AS film_count
FROM category c
JOIN film_category fc ON fc.category_id = c.category_id
GROUP BY c.category_id, c.name
ORDER BY film_count DESC
""")

# Customers with more than 40 rentals (GROUP BY + HAVING)
run("""
SELECT cu.customer_id, cu.first_name, cu.last_name, COUNT(r.rental_id) AS rental_count
FROM customer cu
JOIN rental r ON r.customer_id = cu.customer_id
GROUP BY cu.customer_id, cu.first_name, cu.last_name
HAVING COUNT(r.rental_id) > 40
ORDER BY rental_count DESC
""")
```

**Last cell: close.**

```python
cursor.close()
cnx.close()
connector.close()
```

Then **Kernel → Restart Kernel and Run All Cells**, and **File → Save and Export Notebook As → HTML**.

---

## 7. Starting again in a new session

Cloud Shell keeps your files and installed packages, but **not** shell variables or running processes. Each new session:

```bash
cd ~/sakila-cloudsql-mysql
source infra/env.sh                     # PROJECT_ID, REGION, INSTANCE, DB
./infra/start_jupyter.sh                # venv + INSTANCE_CONNECTION_NAME + password prompt + Jupyter
```

For bash or SQL work outside Jupyter, you only need `source infra/env.sh` (and `read -s MYSQL_ROOT_PW && export MYSQL_ROOT_PW` if a command needs the password).

---

## 8. Pause or shut down

**Pause** (keeps the data and stops compute billing):

```bash
gcloud sql instances patch "$INSTANCE" --activation-policy=NEVER    # stop
gcloud sql instances patch "$INSTANCE" --activation-policy=ALWAYS   # start again
```

**Tear down for good.** First export the notebook and finish your screenshots, because once the instance is deleted the notebook can't run.

```bash
cd ~/sakila-cloudsql-mysql
source infra/env.sh

# Stop Jupyter first (Ctrl+C in its terminal)

./infra/deploy_sakila.sh down                 # deletes the instance after a typed confirmation
# or directly:
# gcloud sql instances delete "$INSTANCE"

gcloud sql instances list               # Listed 0 items.

# Remove downloaded files
rm -rf infra/sakila-db infra/sakila-db.tar.gz sakila-db sakila-db.tar.gz
ls
```

📸 Screenshot: `gcloud sql instances list` showing `Listed 0 items.`

---

## 9. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `... is not a valid project ID` | Used the project name (capitals) | Use the lowercase project ID |
| `gcloud: Invalid choice: 'set'` | Typo | `gcloud config set project ...` |
| `database exists` | Already created | `gcloud sql databases list --instance=...` and carry on |
| `SUPER privilege and binary logging` on import | Triggers/functions in the schema | `--database-flags=log_bin_trust_function_creators=on`, then re-import |
| Payment total 67,406.56, not 67,416.51 | Sakila v1.5 download | Expected; document it |
| `read -s` "hangs" | It's waiting silently for input | Type the password and press Enter |
| Jupyter page blank, `403 Couldn't authenticate` | Preview proxy drops the cookie | Use the token/XSRF flags in `infra/start_jupyter.sh` |
| `KeyError: 'MYSQL_ROOT_PW'` in the notebook | Variables not set before Jupyter started | Stop Jupyter, re-run `./infra/start_jupyter.sh` |
| Connector credentials error | No application-default credentials | `gcloud auth application-default login`, then restart the kernel |
| `claude: command not found` after install | `~/.local/bin` not on PATH | `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc` |
| `history > infra/command_log.sh` wiped your log | `>` overwrites | Write raw history to `history_raw.txt` instead |

---

## 10. Quick reference

```bash
# ---- setup (once) ----
git clone https://github.com/ajace13/sakila-cloudsql-mysql.git ~/sakila-cloudsql-mysql && cd ~/sakila-cloudsql-mysql
cp infra/env.example.sh infra/env.sh && nano infra/env.sh && source infra/env.sh
gcloud config set project "$PROJECT_ID"
gcloud services enable sqladmin.googleapis.com

# ---- instance ----
read -s MYSQL_ROOT_PW && export MYSQL_ROOT_PW
gcloud sql instances create "$INSTANCE" --database-version=MYSQL_8_0 --edition=ENTERPRISE \
  --tier=db-f1-micro --region="$REGION" --root-password="$MYSQL_ROOT_PW"
gcloud sql databases create "$DB" --instance="$INSTANCE"

# ---- data ----
wget https://downloads.mysql.com/docs/sakila-db.tar.gz && tar -xzf sakila-db.tar.gz
gcloud sql connect "$INSTANCE" --user=root --quiet << EOF
source sakila-db/sakila-schema.sql;
source sakila-db/sakila-data.sql;
EOF

# ---- verify ----
gcloud sql connect "$INSTANCE" --user=root      # then the SQL in section 4

# ---- notebook ----
python3 -m venv ~/venv-sakila && source ~/venv-sakila/bin/activate
pip install jupyterlab pandas "cloud-sql-python-connector[pymysql]"
./infra/start_jupyter.sh                               # Web Preview → port 8080

# ---- shut down ----
./infra/deploy_sakila.sh down                          # or: gcloud sql instances delete "$INSTANCE"
gcloud sql instances list                        # Listed 0 items.
rm -rf infra/sakila-db infra/sakila-db.tar.gz sakila-db sakila-db.tar.gz
```
