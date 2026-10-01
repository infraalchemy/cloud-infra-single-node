#!/usr/bin/env bash

set -euo pipefail

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_BLUE='\033[1;34m'
BOLD_RED='\033[1;31m'
NC='\033[0m'

ADMIN_USER="admin"
ADMIN_EMAIL="bordercolliechronicles@gmail.com"

MOODLE_FULL_NAME="Moodle OpenShift Site"
MOODLE_SHORT_NAME="Moodle"

NAMESPACE=$(oc project -q)

ROUTE_HOST=$(oc get route moodle \
  -o jsonpath='{.spec.host}')

FINAL_WWWROOT="http://${ROUTE_HOST}"

echo
echo -e "${BOLD_GREEN}=== Initializing Moodle OpenShift Configuration ===${NC}"
echo

echo -e "${BOLD_CYAN}OpenShift project:${NC} ${NAMESPACE}"
echo -e "${BOLD_CYAN}Moodle URL:${NC} ${FINAL_WWWROOT}"
echo

# ==============================================================================
# WAIT FOR PHP DEPLOYMENT
# ==============================================================================

echo -e "${BOLD_CYAN}Waiting for PHP deployment to be ready...${NC}"

oc rollout status deployment/php --timeout=30m
echo


# ==============================================================================
# LOAD DATABASE CONFIGURATION
# ==============================================================================

echo -e "${BOLD_CYAN}Loading database configuration from OpenShift...${NC}"

DB_HOST=$(oc get service mysql \
  -o jsonpath='{.spec.clusterIP}')

DB_NAME=$(oc get secret mysql-secret \
  -o jsonpath='{.data.mysql-database}' | base64 --decode)

DB_USER=$(oc get secret mysql-secret \
  -o jsonpath='{.data.mysql-user}' | base64 --decode)

DB_PASS=$(oc get secret mysql-secret \
  -o jsonpath='{.data.moodleuser-password}' | base64 --decode)

echo "Database host: $DB_HOST"
echo "Database: $DB_NAME"
echo "Database user: $DB_USER"
echo "Database password: loaded securely"
echo

# ==============================================================================
# MOODLE ADMIN CREDENTIALS
# ==============================================================================

echo -e "${BOLD_CYAN}Checking Moodle admin credentials...${NC}"

if oc get secret moodle-admin-secret > /dev/null 2>&1; then

  echo -e "${BOLD_BLUE}Moodle admin secret already exists.${NC}"

else

  echo -e "${BOLD_BLUE}Moodle admin secret does not exist.${NC}"

  read -s -p "Enter Moodle admin password: " ADMIN_PASS_INPUT
  echo

  oc create secret generic moodle-admin-secret \
    --from-literal=admin-password="$ADMIN_PASS_INPUT"

  unset ADMIN_PASS_INPUT

  echo -e "${BOLD_BLUE}Moodle admin secret created.${NC}"

fi

ADMIN_PASS=$(oc get secret moodle-admin-secret \
  -o jsonpath='{.data.admin-password}' | base64 --decode)

echo

# ==============================================================================
# PREFLIGHT VALIDATION
# ==============================================================================

echo -e "${BOLD_CYAN}Validating Moodle installation configuration...${NC}"

REQUIRED_VARS=(
  DB_HOST
  DB_NAME
  DB_USER
  DB_PASS
  FINAL_WWWROOT
  ADMIN_USER
  ADMIN_PASS
  ADMIN_EMAIL
  MOODLE_FULL_NAME
  MOODLE_SHORT_NAME
)

for VAR_NAME in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR_NAME:-}" ]]; then
    echo -e "${BOLD_RED}ERROR: ${VAR_NAME} is empty.${NC}"
    exit 1
  fi
done

echo -e "${BOLD_BLUE}Moodle configuration preflight passed.${NC}"
echo


# ==============================================================================
# INSTALL MOODLE
# ==============================================================================

echo -e "${BOLD_CYAN}Checking Moodle installation status...${NC}"

if MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
  test -f /var/www/html/config.php; then

  echo -e "${BOLD_BLUE}Moodle config.php already exists. Skipping Moodle installation.${NC}"

else

  echo -e "${BOLD_BLUE}Moodle is not installed. Starting CLI installation.${NC}"

  MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
    php /var/www/html/admin/cli/install.php \
      --lang=en \
      --dbtype=mysqli \
      --dbhost="$DB_HOST" \
      --dbport=3306 \
      --dbname="$DB_NAME" \
      --dbuser="$DB_USER" \
      --dbpass="$DB_PASS" \
      --dataroot="/moodledata" \
      --wwwroot="$FINAL_WWWROOT" \
      --fullname="$MOODLE_FULL_NAME" \
      --shortname="$MOODLE_SHORT_NAME" \
      --adminuser="$ADMIN_USER" \
      --adminpass="$ADMIN_PASS" \
      --adminemail="$ADMIN_EMAIL" \
      --agree-license \
      --non-interactive

  echo -e "${BOLD_GREEN}Moodle CLI installation completed successfully.${NC}"

fi

echo

# ==============================================================================
# INSTALL MOODLE
# ==============================================================================

echo -e "${BOLD_CYAN}Checking Moodle installation status...${NC}"

if MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
  test -f /var/www/html/config.php; then

  echo -e "${BOLD_BLUE}Moodle config.php already exists. Skipping Moodle installation.${NC}"

else

  echo -e "${BOLD_BLUE}Moodle is not installed. Starting CLI installation.${NC}"

  MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
    php /var/www/html/admin/cli/install.php \
      --lang=en \
      --dbtype=mysqli \
      --dbhost="$DB_HOST" \
      --dbport=3306 \
      --dbname="$DB_NAME" \
      --dbuser="$DB_USER" \
      --dbpass="$DB_PASS" \
      --dataroot="/moodledata" \
      --wwwroot="$FINAL_WWWROOT" \
      --fullname="$MOODLE_FULL_NAME" \
      --shortname="$MOODLE_SHORT_NAME" \
      --adminuser="$ADMIN_USER" \
      --adminpass="$ADMIN_PASS" \
      --adminemail="$ADMIN_EMAIL" \
      --agree-license \
      --non-interactive

  echo -e "${BOLD_GREEN}Moodle CLI installation completed successfully.${NC}"

fi

echo

  echo -e "${BOLD_GREEN}Moodle CLI installation completed successfully.${NC}"

fi

echo

# ==============================================================================
# CONFIGURE MOODLE PROXY SETTINGS
# ==============================================================================

echo -e "${BOLD_CYAN}Configuring Moodle proxy settings...${NC}"

if MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
  grep -q '\$CFG->getremoteaddrconf = 2;' /var/www/html/config.php; then

  echo -e "${BOLD_BLUE}getremoteaddrconf is already configured.${NC}"

else

  echo -e "${BOLD_BLUE}Adding getremoteaddrconf.${NC}"

  MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
    sed -i \
    "/require_once/i \$CFG->getremoteaddrconf = 2;" \
    /var/www/html/config.php

fi

echo