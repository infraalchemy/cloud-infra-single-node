#!/usr/bin/env bash

BOLD_CYAN='\033[1;36m'
NC='\033[0m'

BOLD_GREEN='\033[1;32m'
NC='\033[0m'

set -euo pipefail



# ==============================================================================
# CONFIGURATION CONSTANTS
# ==============================================================================


CLUSTER_NAME="moodle-gke-cluster"
ZONE="northamerica-northeast2-a"

ADMIN_USER="admin"
ADMIN_EMAIL="bordercolliechronicles@gmail.com"

MOODLE_FULL_NAME="Moodle Production Site"
MOODLE_SHORT_NAME="Moodle"
DOMAIN_NAME="https://bordercolliechronicles.ca"

echo
echo -e "${BOLD_GREEN}=== Initializing Automated Moodle CLI Installer ===${NC}"
echo

echo -e "${BOLD_CYAN}1. Connecting kubectl to GKE cluster...:${NC}"
gcloud container clusters get-credentials "$CLUSTER_NAME" --zone "$ZONE"
echo

echo -e "${BOLD_CYAN}Waiting for PHP deployment to be ready...${NC}"
kubectl rollout status deployment/php --timeout=30m
echo

echo
echo -e "${BOLD_CYAN}2. Load database configuration from Kubernetes Secret:${NC}"
DB_NAME=$(kubectl get secret mysql-secret \
  -o jsonpath='{.data.mysql-database}' | base64 --decode)
echo "Database: $DB_NAME"

DB_USER=$(kubectl get secret mysql-secret \
  -o jsonpath='{.data.mysql-user}' | base64 --decode)
echo "Database user: $DB_USER"

DB_PASS=$(kubectl get secret mysql-secret \
  -o jsonpath='{.data.moodleuser-password}' | base64 --decode)
echo "Database password: loaded securely"

echo
echo -e "${BOLD_CYAN}Checking Moodle admin credentials:${NC}"

if kubectl get secret moodle-admin-secret > /dev/null 2>&1; then
  echo "Moodle admin secret already exists."
else
  echo "Moodle admin secret does not exist."

  read -s -p "Enter Moodle admin password: " ADMIN_PASS_INPUT
  echo

  kubectl create secret generic moodle-admin-secret \
    --from-literal=admin-password="$ADMIN_PASS_INPUT"

  unset ADMIN_PASS_INPUT

  echo "Moodle admin secret created."
fi

ADMIN_PASS=$(kubectl get secret moodle-admin-secret \
  -o jsonpath='{.data.admin-password}' | base64 --decode)
echo

DB_HOST="mysql"
echo "Database host: $DB_HOST"
echo

echo
# 4. Moodle CLI installation
echo -e "${BOLD_CYAN}Checking Moodle installation status...${NC}"

if MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- test -f /var/www/html/config.php; then
  echo "Moodle config.php already exists. Skipping Moodle installation."
else
  echo "Moodle is not installed. Starting CLI installation."

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- php /var/www/html/admin/cli/install.php \
    --lang=en \
    --dbtype=mysqli \
    --dbhost="$DB_HOST" \
    --dbport=3306 \
    --dbname="$DB_NAME" \
    --dbuser="$DB_USER" \
    --dbpass="$DB_PASS" \
    --dataroot="/moodledata" \
    --wwwroot="$DOMAIN_NAME" \
    --fullname="$MOODLE_FULL_NAME" \
    --shortname="$MOODLE_SHORT_NAME" \
    --adminuser="$ADMIN_USER" \
    --adminpass="$ADMIN_PASS" \
    --adminemail="$ADMIN_EMAIL" \
    --agree-license \
    --non-interactive

  echo "Moodle base installer completed successfully."
fi
echo

echo
echo -e "${BOLD_CYAN}Checking Moodle proxy configuration...${NC}"

REMOTE_ADDR_CONFIGURED=false
SSL_PROXY_CONFIGURED=false

if MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  grep -q '\$CFG->getremoteaddrconf = 2;' /var/www/html/config.php; then
  REMOTE_ADDR_CONFIGURED=true
  echo "getremoteaddrconf is configured."
else
  echo "getremoteaddrconf is missing."
fi

if MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  grep -q '\$CFG->sslproxy = 1;' /var/www/html/config.php; then
  SSL_PROXY_CONFIGURED=true
  echo "sslproxy is configured."
else
  echo "sslproxy is missing."
fi

if [[ "$REMOTE_ADDR_CONFIGURED" == true && "$SSL_PROXY_CONFIGURED" == true ]]; then
  echo "Moodle proxy configuration is already complete."

else
  echo "Moodle proxy configuration needs to be updated."
  echo "Replacing config.php with known-good configuration..."

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- sh -c "cat << EOF > /var/www/html/config.php
<?php  // Moodle configuration file

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mysqli';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = '${DB_HOST}';
\$CFG->dbname    = '${DB_NAME}';
\$CFG->dbuser    = '${DB_USER}';
\$CFG->dbpass    = '${DB_PASS}';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => 3306,
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

\$CFG->wwwroot   = '${DOMAIN_NAME}';
\$CFG->dataroot  = '/moodledata';
\$CFG->admin     = 'admin';
\$CFG->directorypermissions = 02777;

\$CFG->getremoteaddrconf = 2;
\$CFG->sslproxy = 1;

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF"

  echo "Moodle config.php replaced successfully."
fi

echo
echo
echo -e "${BOLD_CYAN}Setting Moodle file permissions...${NC}"

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- chown 33:33 /var/www/html/config.php
MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- chmod 644 /var/www/html/config.php
MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- chmod 777 /moodledata
MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- chown -R 33:33 /moodledata

echo
echo -e "${BOLD_CYAN}Verifying Moodle configuration file...${NC}"
MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- ls -lh /var/www/html/config.php

echo
echo "Moodle installation and configuration completed successfully."
echo
