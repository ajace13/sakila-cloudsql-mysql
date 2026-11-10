#!/bin/bash
# Start JupyterLab in Google Cloud Shell with the two variables the notebooks read, then open it with
# Web Preview -> port 8080.
#
# Jupyter's own token check is off because Cloud Shell's preview proxy drops Jupyter's login cookie
# (blank page, "403 Couldn't authenticate"). That is only acceptable because the Web Preview URL is already
# restricted to your signed-in Google account and the Cloud Shell VM takes no other inbound traffic, so this
# script refuses to run anywhere else.
set -euo pipefail
[ "${CLOUD_SHELL:-}" = "true" ] || { echo "Run this only inside Google Cloud Shell (Jupyter auth is disabled)." >&2; exit 1; }

cd "$(dirname "$0")/.."
# shellcheck source=/dev/null
source ./infra/env.sh
# shellcheck source=/dev/null
source ~/venv-sakila/bin/activate

INSTANCE_CONNECTION_NAME="$(gcloud sql instances describe "$INSTANCE" --format='value(connectionName)')"
export INSTANCE_CONNECTION_NAME
read -r -s -p "MySQL root password: " MYSQL_ROOT_PW && export MYSQL_ROOT_PW && echo

jupyter lab --no-browser --port=8080 --ip=0.0.0.0 \
  --ServerApp.allow_origin='*' --ServerApp.disable_check_xsrf=True \
  --IdentityProvider.token='' --ServerApp.password=''
