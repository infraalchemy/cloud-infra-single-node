#!/usr/bin/env bash

set -euo pipefail

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_BLUE='\033[1;34m'
BOLD_RED='\033[1;31m'
NC='\033[0m'


# ==============================================================================
# CONFIGURATION CONSTANTS
# ==============================================================================

ADMIN_USER="admin"
ADMIN_EMAIL="bordercolliechronicles@gmail.com"

MOODLE_FULL_NAME="Moodle ARO Site"
MOODLE_SHORT_NAME="Moodle"


echo
echo -e "${BOLD_GREEN}=== Initializing Automated Moodle CLI Installer ===${NC}"
echo


echo -e "${BOLD_CYAN}1. Loading database configuration from ARO...${NC}"

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


echo
echo -e "${BOLD_CYAN}2. Retrieving ARO Route...${NC}"

ROUTE_HOST=$(oc get route moodle \
  -o jsonpath='{.spec.host}')

FINAL_WWWROOT="https://${ROUTE_HOST}"

echo -e "${BOLD_BLUE}Route host: ${ROUTE_HOST}${NC}"
echo -e "${BOLD_BLUE}Moodle URL: ${FINAL_WWWROOT}${NC}"
echo

echo
echo -e "${BOLD_CYAN}3. Checking Moodle admin credentials...${NC}"

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

echo
echo -e "${BOLD_CYAN}4. Checking Moodle installation status...${NC}"

if MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
  test -f /var/www/html/config.php; then

  echo -e "${BOLD_BLUE}Moodle config.php already exists. Skipping Moodle installation.${NC}"

else

  echo -e "${BOLD_BLUE}Moodle is not installed. Starting CLI installation.${NC}"
  echo
  echo "Database host: ${DB_HOST}"
  echo "Database: ${DB_NAME}"
  echo "Database user: ${DB_USER}"
  echo "Moodle data directory: /moodledata"
  echo "Moodle URL: ${FINAL_WWWROOT}"
  echo

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

  echo
  echo -e "${BOLD_BLUE}Moodle base installation completed successfully.${NC}"

fi

echo


echo
echo -e "${BOLD_CYAN}5. Checking Moodle proxy configuration...${NC}"

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

if MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
  grep -q '\$CFG->sslproxy = 1;' /var/www/html/config.php; then

  echo -e "${BOLD_BLUE}sslproxy is already configured.${NC}"

else

  echo -e "${BOLD_BLUE}Adding sslproxy.${NC}"

  MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
    sed -i \
    "/require_once/i \$CFG->sslproxy = 1;" \
    /var/www/html/config.php

fi

echo

echo
echo -e "${BOLD_CYAN}6. Verifying Moodle configuration...${NC}"

MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
  php -l /var/www/html/config.php

echo

MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
  grep -E 'wwwroot|getremoteaddrconf|sslproxy' \
  /var/www/html/config.php

echo

MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
  ls -lh /var/www/html/config.php

echo

echo
echo -e "${BOLD_CYAN}7. Verifying PHP persistence...${NC}"

OLD_PHP_POD=$(oc get pods -l app=php \
  -o jsonpath='{.items[0].metadata.name}')

echo -e "${BOLD_BLUE}Deleting PHP pod: ${OLD_PHP_POD}${NC}"

oc delete pod "$OLD_PHP_POD"

echo
echo "Waiting for replacement PHP pod..."

oc rollout status deployment/php --timeout=60m

NEW_PHP_POD=$(oc get pods -l app=php \
  -o jsonpath='{.items[0].metadata.name}')

echo -e "${BOLD_BLUE}Old PHP pod: ${OLD_PHP_POD}${NC}"
echo -e "${BOLD_BLUE}New PHP pod: ${NEW_PHP_POD}${NC}"

echo
echo -e "${BOLD_CYAN}Verify Moodle application files survived pod replacement...${NC}"

MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
  ls -l /var/www/html/config.php

echo
echo -e "${BOLD_BLUE}Verify Moodle data survived pod replacement...${NC}"

MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
  ls -la /moodledata

echo

echo
echo -e "${BOLD_CYAN}8. Verifying MYSQL persistence...${NC}"

OLD_MYSQL_POD=$(oc get pods -l app=mysql \
  -o jsonpath='{.items[0].metadata.name}')

echo -e "${BOLD_BLUE}Deleting MySQL pod: ${OLD_MYSQL_POD}${NC}"

oc delete pod "$OLD_MYSQL_POD"

echo
echo "Waiting for replacement MySQL pod..."

oc rollout status deployment/mysql --timeout=5m

NEW_MYSQL_POD=$(oc get pods -l app=mysql \
  -o jsonpath='{.items[0].metadata.name}')

echo -e "${BOLD_BLUE}Old MySQL pod: ${OLD_MYSQL_POD}${NC}"
echo -e "${BOLD_BLUE}New MySQL pod: ${NEW_MYSQL_POD}${NC}"

echo
echo "Waiting for MySQL to accept connections..."

until oc exec deployment/mysql -- \
  mysqladmin ping \
    --protocol=TCP \
    -h 127.0.0.1 \
    -u"$DB_USER" \
    -p"$DB_PASS" \
    --silent
do
  echo "MySQL is not ready yet. Waiting 5 seconds..."
  sleep 5
done

echo -e "${BOLD_BLUE}MySQL is ready.${NC}"

echo
echo "Verifying MySQL database still exists..."

MYSQL_READY=false

for attempt in {1..24}; do

  if oc exec deployment/mysql -- \
    mysqladmin ping \
      --protocol=TCP \
      -h 127.0.0.1 \
      -u"$DB_USER" \
      -p"$DB_PASS" \
      --silent; then

    MYSQL_READY=true
    break
  fi

  echo "MySQL is not ready yet. Waiting 5 seconds... ($attempt/24)"
  sleep 5

done

if [[ "$MYSQL_READY" != "true" ]]; then
  echo -e "${BOLD_RED}ERROR: MySQL did not become ready within 2 minutes.${NC}"
  exit 1
fi

echo -e "${BOLD_BLUE}MySQL is ready.${NC}"

echo
echo -e "${BOLD_CYAN}9. Display Final Configuration${NC}"

MSYS_NO_PATHCONV=1 oc exec deployment/php -c php -- \
  tail -n 20 /var/www/html/config.php

echo

echo
echo -e "${BOLD_CYAN}10. Testing ARO Route over HTTPS...${NC}"

ROUTE_READY=false

for attempt in {1..12}; do

  if curl -fsSI --max-time 15 "$FINAL_WWWROOT" > /dev/null; then
    ROUTE_READY=true
    break
  fi

  echo "Route not ready yet. Retrying in 10 seconds... ($attempt/12)"
  sleep 10

done

if [ "$ROUTE_READY" = true ]; then

  echo -e "${BOLD_BLUE}ARO Route is responding successfully.${NC}"
  curl -I --max-time 15 "$FINAL_WWWROOT"

else

  echo -e "${BOLD_RED}ARO Route test failed after waiting for the Route to become ready.${NC}"
  echo "Check the Route, Nginx Service, Nginx pod, PHP Service, and PHP pod."

fi

echo

echo -e "${BOLD_GREEN}Moodle installation and configuration completed.${NC}"

echo




























