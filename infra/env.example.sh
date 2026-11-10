# shellcheck shell=bash
# Copy to env.sh (git-ignored) and fill in. Non-secret settings only: the root password is never stored;
# deploy_sakila.sh asks for it with a hidden prompt, or reads MYSQL_ROOT_PW if you exported it this session.
export PROJECT_ID=your-project-id     # the lowercase project ID, not the display name
export REGION=us-central1
export INSTANCE=sakila-mysql
export DB=sakila
