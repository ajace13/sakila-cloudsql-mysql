#!/bin/bash
# Deploy Sakila to Cloud SQL (MySQL 8.0). Usage: ./infra/deploy_sakila.sh [up|down]
set -euo pipefail

cd "$(dirname "$0")"

# PROJECT_ID, REGION, INSTANCE, DB come from env.sh; values are never printed
source ./env.sh
: "${PROJECT_ID:?PROJECT_ID is not set in env.sh}"
: "${REGION:?REGION is not set in env.sh}"
: "${INSTANCE:?INSTANCE is not set in env.sh}"
: "${DB:?DB is not set in env.sh}"

die() { echo "$*" >&2; exit 1; }

# The supplied SQL scripts target the sakila schema only
[ "$DB" = "sakila" ] || die "DB must be 'sakila'. Stopping before any changes."

export CLOUDSDK_CORE_PROJECT="$PROJECT_ID"

SAKILA_URL="https://downloads.mysql.com/docs/sakila-db.tar.gz"
SAKILA_DIR="sakila-db"

# Return 0 if found, 1 if the lookup succeeded with no match.
# A failed gcloud call stops the script (the || die runs even inside an if).
instance_exists() {
  local found
  found="$(gcloud sql instances list --filter="name=$INSTANCE" --format='value(name)')" \
    || die "Could not look up the instance. Stopping."
  [ "$found" = "$INSTANCE" ]
}

database_exists() {
  local found
  found="$(gcloud sql databases list --instance="$INSTANCE" --filter="name=$DB" --format='value(name)')" \
    || die "Could not look up the database. Stopping."
  [ "$found" = "$DB" ]
}

# SQL on stdin. mysql prompts for the root password on the terminal each session.
run_sql() {
  gcloud sql connect "$INSTANCE" --user=root --quiet
}

# field "<output>" "<key>": value of the last "key=value" line
field() {
  printf '%s\n' "$1" | sed -n "s/^$2=//p" | tail -n 1
}

count_objects() {
  local sql out n
  sql="SELECT CONCAT('objects=', (
    (SELECT COUNT(*) FROM information_schema.tables   WHERE table_schema='$DB')
  + (SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema='$DB')
  + (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='$DB')
  + (SELECT COUNT(*) FROM information_schema.events   WHERE event_schema='$DB')
  )) AS result;"
  out="$(printf '%s\n' "$sql" | run_sql)" || die "Could not inspect the schema. Stopping."
  n="$(field "$out" objects)"
  [[ "$n" =~ ^[0-9]+$ ]] || die "Unexpected result when inspecting the schema. Stopping."
  echo "$n"
}

# Only called on a schema confirmed empty. Schema first, then data.
import_sakila() {
  local out
  out="$(printf '%s\n' \
    "source $SAKILA_DIR/sakila-schema.sql;" \
    "source $SAKILA_DIR/sakila-data.sql;" \
    "SELECT 'import=ok' AS result;" | run_sql)" \
    || die "Import failed. Nothing was retried or rebuilt; inspect the database before re-running."
  [ "$(field "$out" import)" = "ok" ] \
    || die "Import did not complete. Nothing was retried or rebuilt; inspect the database before re-running."
}

# Read-only: three SELECTs, never imports or modifies data
verify_sakila() {
  local sql out tables films total
  sql="SELECT CONCAT('base_tables=', COUNT(*)) AS result FROM information_schema.tables WHERE table_schema='$DB' AND table_type='BASE TABLE';
SELECT CONCAT('films=', COUNT(*)) AS result FROM $DB.film;
SELECT CONCAT('payment_total=', ROUND(SUM(amount),2)) AS result FROM $DB.payment;"

  if ! out="$(printf '%s\n' "$sql" | run_sql)"; then
    die "Verification queries failed. Nothing was changed; the data may be missing or incomplete."
  fi

  tables="$(field "$out" base_tables)"
  films="$(field "$out" films)"
  total="$(field "$out" payment_total)"

  echo "Verification (compare with the known values in CLAUDE.md):"
  echo "  base tables:   $tables"
  echo "  films:         $films"
  echo "  payment total: $total"

  if [[ ! "$tables" =~ ^[0-9]+$ || ! "$films" =~ ^[0-9]+$ || ! "$total" =~ ^[0-9]+\.[0-9]{2}$ ]] \
     || [ "$tables" -eq 0 ] || [ "$films" -eq 0 ]; then
    die "Verification found missing or empty data. Nothing was changed or rebuilt; inspect the database before taking action."
  fi
}

down() {
  if ! instance_exists; then
    echo "Instance does not exist; nothing to delete."
    return 0
  fi
  read -r -p "This permanently deletes the Cloud SQL instance and all its data. Type 'delete' to confirm: " answer
  [ "$answer" = "delete" ] || die "Aborted."
  gcloud sql instances delete "$INSTANCE" --quiet
  echo "Instance deleted."
}

up() {
  gcloud services enable sqladmin.googleapis.com

  if instance_exists; then
    echo "Instance already exists; skipping create."
  else
    if [ -z "${MYSQL_ROOT_PW:-}" ]; then
      read -r -s -p "MySQL root password: " MYSQL_ROOT_PW
      echo
    fi
    echo "Creating instance (this takes several minutes)..."
    gcloud sql instances create "$INSTANCE" \
      --database-version=MYSQL_8_0 --edition=ENTERPRISE \
      --tier=db-f1-micro --region="$REGION" \
      --root-password="$MYSQL_ROOT_PW"
  fi

  if database_exists; then
    echo "Database already exists; skipping create."
  else
    gcloud sql databases create "$DB" --instance="$INSTANCE"
  fi

  if [ -f "$SAKILA_DIR/sakila-schema.sql" ] && [ -f "$SAKILA_DIR/sakila-data.sql" ]; then
    echo "Sakila files already present; skipping download."
  else
    echo "Downloading Sakila..."
    curl -fsSL -o sakila-db.tar.gz.part "$SAKILA_URL"
    mv sakila-db.tar.gz.part sakila-db.tar.gz
    tar -xzf sakila-db.tar.gz
    [ -f "$SAKILA_DIR/sakila-schema.sql" ] && [ -f "$SAKILA_DIR/sakila-data.sql" ] \
      || die "Sakila SQL files not found after unpacking. Stopping."
  fi

  echo "Checking whether the schema is empty (you will be asked for the root password)..."
  local objects
  objects="$(count_objects)" || die "Schema inspection failed. Stopping."
  if [ "$objects" -eq 0 ]; then
    echo "Schema is empty; importing schema then data (password prompt)..."
    import_sakila
  else
    echo "Schema already contains objects; skipping import. Nothing will be dropped or reloaded."
  fi

  echo "Running verification (password prompt)..."
  verify_sakila
}

case "${1:-up}" in
  up)   up ;;
  down) down ;;
  *)    echo "Usage: $0 [up|down]" >&2; exit 2 ;;
esac
