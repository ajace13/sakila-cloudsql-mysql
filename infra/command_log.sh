#!/bin/bash
# The commands I ran in Cloud Shell, in order (folder names changed for publishing; deploy_sakila.sh is the repeatable version)
# A record of what was typed, not a script to run: shellcheck warnings about interactive cd/source are expected.
# shellcheck disable=SC2164,SC1090

# Project folder and configuration

mkdir -p ~/sakila-cloudsql-mysql
cd ~/sakila-cloudsql-mysql
git init

nano env.sh
vi env.sh                                  
source env.sh
gcloud config get-value project           

echo "env.sh" > .gitignore
echo "sakila-db/" >> .gitignore
echo "*.tar.gz" >> .gitignore

# Create the instance
gcloud services enable sqladmin.googleapis.com

INSTANCE_NAME="sakila-mysql"
read -s MYSQL_ROOT_PW && export MYSQL_ROOT_PW     

gcloud sql instances create $INSTANCE_NAME \
  --database-version=MYSQL_8_0 --edition=ENTERPRISE \
  --tier=db-f1-micro --region=us-central1 \
  --root-password="$MYSQL_ROOT_PW"

gcloud sql databases create sakila --instance=$INSTANCE_NAME
gcloud sql databases list --instance=$INSTANCE_NAME

# Download and import Sakila
wget https://downloads.mysql.com/docs/sakila-db.tar.gz
tar -xzf sakila-db.tar.gz
ls sakila-db

gcloud sql connect $INSTANCE_NAME --user=root --quiet << EOF
source sakila-db/sakila-schema.sql;
source sakila-db/sakila-data.sql;
SHOW DATABASES;
EOF

# Verify
gcloud sql connect $INSTANCE_NAME --user=root --quiet << EOF
USE sakila;
SHOW FULL TABLES WHERE Table_type = 'BASE TABLE';
SELECT COUNT(*) FROM film;
SELECT ROUND(SUM(amount),2) FROM payment;
EOF


gcloud sql connect $INSTANCE_NAME --user=root --quiet << EOF
USE sakila;
SELECT COUNT(*) AS payments, ROUND(SUM(amount),2) AS total FROM payment;
SELECT COUNT(*) AS rentals FROM rental;
SELECT COUNT(*) AS actors FROM actor;
SELECT COUNT(*) AS customers FROM customer;
EOF

# Interactive verification for the screenshots
gcloud sql connect $INSTANCE_NAME --user=root
#   mysql> USE sakila;
#   mysql> SHOW FULL TABLES WHERE Table_type = 'BASE TABLE';
#   mysql> SELECT COUNT(*) FROM film;
#   mysql> SELECT ROUND(SUM(amount),2) FROM payment;
#   mysql> exit

# Python environment and Jupyter
python3 -m venv ~/venv-sakila
source ~/venv-sakila/bin/activate
pip install notebook pandas "cloud-sql-python-connector[pymysql]"
pip install jupyterlab

cat > start_jupyter.sh << 'EOF'
#!/bin/bash
# Start Jupyter in Cloud Shell, connected to Cloud SQL via env vars
source ~/venv-sakila/bin/activate
export INSTANCE_CONNECTION_NAME="$(gcloud sql instances describe sakila-mysql --format='value(connectionName)')"
read -s -p "MySQL root password: " MYSQL_ROOT_PW && export MYSQL_ROOT_PW && echo
cd ~/sakila-cloudsql-mysql
jupyter lab --no-browser --port=8080 --ip=0.0.0.0 \
  --ServerApp.allow_origin='*' --ServerApp.disable_check_xsrf=True \
  --IdentityProvider.token='' --ServerApp.password=''
EOF
chmod +x start_jupyter.sh
./start_jupyter.sh                         

# Claude Code setup
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
claude

# ============================================================
# Clean up: ./infra/deploy_sakila.sh down (deletes the instance after a typed confirmation)
# ============================================================