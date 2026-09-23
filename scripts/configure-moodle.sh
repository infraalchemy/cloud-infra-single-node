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

PROJECT_ID="civic-champion-439320-a5"
LOCATION="northamerica-northeast2"
CLUSTER_NAME="moodle-gke-cluster"
ZONE="northamerica-northeast2-a"

ADMIN_USER="admin"
ADMIN_EMAIL="bordercolliechronicles@gmail.com"

MOODLE_FULL_NAME="Moodle Production Site"
MOODLE_SHORT_NAME="Moodle"

DOMAIN_NAME="bordercolliechronicles.ca"
FINAL_WWWROOT="https://${DOMAIN_NAME}"


echo
echo -e "${BOLD_GREEN}=== Initializing Automated Moodle CLI Installer ===${NC}"
echo


echo -e "${BOLD_CYAN}1. Connecting kubectl to GKE cluster...${NC}"

gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --zone "$ZONE" \
  --project "$PROJECT_ID"
echo

echo
echo -e "${BOLD_CYAN}Waiting for PHP deployment to be ready...${NC}"

kubectl rollout status deployment/php --timeout=30m
echo

echo
echo -e "${BOLD_CYAN}2. Loading database configuration from Kubernetes...${NC}"

DB_HOST=$(kubectl get service mysql \
  -o jsonpath='{.spec.clusterIP}')

DB_NAME=$(kubectl get secret mysql-secret \
  -o jsonpath='{.data.mysql-database}' | base64 --decode)

DB_USER=$(kubectl get secret mysql-secret \
  -o jsonpath='{.data.mysql-user}' | base64 --decode)

DB_PASS=$(kubectl get secret mysql-secret \
  -o jsonpath='{.data.moodleuser-password}' | base64 --decode)

echo "Database host: $DB_HOST"
echo "Database: $DB_NAME"
echo "Database user: $DB_USER"
echo "Database password: loaded securely"
echo

echo
echo -e "${BOLD_CYAN}3. Retrieving GKE static IP...${NC}"

STATIC_IP=$(gcloud compute addresses describe moodle-static-ip \
  --global \
  --project="$PROJECT_ID" \
  --format="value(address)")

echo -e "${BOLD_BLUE}Static IP: $STATIC_IP${NC}"
echo

echo
echo -e "${BOLD_CYAN}4. Checking Moodle admin credentials...${NC}"

if kubectl get secret moodle-admin-secret > /dev/null 2>&1; then

  echo -e "${BOLD_BLUE}Moodle admin secret already exists.${NC}"

else

  echo -e "${BOLD_BLUE}Moodle admin secret does not exist.${NC}"

  read -s -p "Enter Moodle admin password: " ADMIN_PASS_INPUT
  echo

  kubectl create secret generic moodle-admin-secret \
    --from-literal=admin-password="$ADMIN_PASS_INPUT"

  unset ADMIN_PASS_INPUT

  echo -e "${BOLD_BLUE}Moodle admin secret created.${NC}"

fi

ADMIN_PASS=$(kubectl get secret moodle-admin-secret \
  -o jsonpath='{.data.admin-password}' | base64 --decode)

echo

echo
echo -e "${BOLD_CYAN}5. Checking Moodle installation status...${NC}"

if MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  test -f /var/www/html/config.php; then

  echo -e "${BOLD_BLUE}Moodle config.php already exists. Skipping Moodle installation.${NC}"

else

  echo -e "${BOLD_BLUE}Moodle is not installed. Starting CLI installation.${NC}"

  #
  # Moodle is initially installed using the HTTP static IP.
  # After installation, config.php is updated to use the final HTTPS domain.
  #

  MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
    php /var/www/html/admin/cli/install.php \
      --lang=en \
      --dbtype=mysqli \
      --dbhost="$DB_HOST" \
      --dbport=3306 \
      --dbname="$DB_NAME" \
      --dbuser="$DB_USER" \
      --dbpass="$DB_PASS" \
      --dataroot="/moodledata" \
      --wwwroot="http://${STATIC_IP}" \
      --fullname="$MOODLE_FULL_NAME" \
      --shortname="$MOODLE_SHORT_NAME" \
      --adminuser="$ADMIN_USER" \
      --adminpass="$ADMIN_PASS" \
      --adminemail="$ADMIN_EMAIL" \
      --agree-license \
      --non-interactive

  echo -e "${BOLD_BLUE}Moodle base installation completed successfully.${NC}"

fi

echo

echo
echo -e "${BOLD_CYAN}6. Configuring final Moodle HTTPS URL...${NC}"

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  sed -i \
  "s|^\(\$CFG->wwwroot[[:space:]]*=[[:space:]]*\).*;|\1'${FINAL_WWWROOT}';|" \
  /var/www/html/config.php

echo -e "${BOLD_BLUE}Moodle wwwroot set to: $FINAL_WWWROOT${NC}"

echo

echo
echo -e "${BOLD_CYAN}7. Checking Moodle proxy configuration...${NC}"

if MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  grep -q '\$CFG->getremoteaddrconf = 2;' /var/www/html/config.php; then

  echo -e "${BOLD_BLUE}getremoteaddrconf is already configured.${NC}"

else

  echo -e "${BOLD_BLUE}Adding getremoteaddrconf.${NC}"

  MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
    sed -i \
    "/require_once/i \$CFG->getremoteaddrconf = 2;" \
    /var/www/html/config.php

fi


if MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  grep -q '\$CFG->sslproxy = 1;' /var/www/html/config.php; then

  echo -e "${BOLD_BLUE}sslproxy is already configured.${NC}"

else

  echo -e "${BOLD_BLUE}Adding sslproxy.${NC}"

  MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
    sed -i \
    "/require_once/i \$CFG->sslproxy = 1;" \
    /var/www/html/config.php

fi

echo

echo
echo -e "${BOLD_CYAN}8. Setting Moodle permissions...${NC}"

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  chown 33:33 /var/www/html/config.php

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  chmod 644 /var/www/html/config.php

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  chown -R 33:33 /moodledata

echo

echo
echo -e "${BOLD_CYAN}9. Verifying Moodle configuration...${NC}"

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  php -l /var/www/html/config.php

echo

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  grep -E 'wwwroot|getremoteaddrconf|sslproxy' \
  /var/www/html/config.php

echo

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  ls -lh /var/www/html/config.php

echo


echo
echo -e "${BOLD_CYAN}10. Verifying PHP persistence...${NC}"

OLD_PHP_POD=$(kubectl get pods -l app=php \
  -o jsonpath='{.items[0].metadata.name}')

echo -e "${BOLD_BLUE}Deleting PHP pod: ${OLD_PHP_POD}${NC}"

kubectl delete pod "$OLD_PHP_POD"

echo
echo "Waiting for replacement PHP pod..."

kubectl rollout status deployment/php --timeout=30m

NEW_PHP_POD=$(kubectl get pods -l app=php \
  -o jsonpath='{.items[0].metadata.name}')

echo -e "${BOLD_BLUE}Old PHP pod: ${OLD_PHP_POD}${NC}"
echo -e "${BOLD_BLUE}New PHP pod: ${NEW_PHP_POD}${NC}"

echo
echo -e "${BOLD_CYAN}Verify Moodle application files survived pod replacement...${NC}"

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  ls -l /var/www/html/config.php

echo
echo "Verify Moodle data survived pod replacement..."

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  ls -la /moodledata

echo

echo
echo -e "${BOLD_CYAN}11. Display Final Configuration${NC}"

MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  tail -n 20 /var/www/html/config.php

echo


echo
echo
echo -e "${BOLD_CYAN}12. Testing domain routing over HTTP...${NC}"

if curl -fsSI --max-time 15 "http://${DOMAIN_NAME}" > /dev/null; then

  echo -e "${BOLD_BLUE}HTTP domain routing is responding successfully.${NC}"
  curl -I "http://${DOMAIN_NAME}"

else

  echo -e "${BOLD_RED}HTTP domain routing test failed.${NC}"
  echo "Check DNS, static IP, Ingress, and backend health."

fi

echo


echo
echo
echo -e "${BOLD_CYAN}13. Waiting for Google-managed SSL certificate...${NC}"

CERT_NAME="moodle-ssl-cert"
MAX_ATTEMPTS=20
WAIT_SECONDS=30
CERT_STATUS=""

for ATTEMPT in $(seq 1 "$MAX_ATTEMPTS"); do

  CERT_STATUS=$(kubectl get managedcertificate "$CERT_NAME" \
    -o jsonpath='{.status.certificateStatus}' 2>/dev/null || true)

  echo "Certificate status: ${CERT_STATUS:-Unavailable} (${ATTEMPT}/${MAX_ATTEMPTS})"

  if [[ "$CERT_STATUS" == "Active" ]]; then
    echo -e "${BOLD_GREEN}Managed certificate is Active.${NC}"
    break
  fi

  if [[ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]]; then
    echo "Waiting ${WAIT_SECONDS} seconds before checking again..."
    sleep "$WAIT_SECONDS"
  fi

done

if [[ "$CERT_STATUS" != "Active" ]]; then
  echo -e "${BOLD_BLUE}Managed certificate is still ${CERT_STATUS:-Unavailable}.${NC}"
  echo "HTTPS verification will be skipped for now."
fi

echo


echo
echo -e "${BOLD_CYAN}14. Testing final HTTPS endpoint...${NC}"

if [[ "$CERT_STATUS" == "Active" ]]; then

  if curl -fsSI --max-time 15 "$FINAL_WWWROOT" > /dev/null; then

    echo -e "${BOLD_BLUE}HTTPS endpoint is responding successfully.${NC}"
    curl -I "$FINAL_WWWROOT"

  else

    echo -e "${BOLD_BLUE}Certificate is Active, but HTTPS endpoint test failed.${NC}"
    echo "Final URL: $FINAL_WWWROOT"

  fi

else

  echo -e "${BOLD_BLUE}Skipping HTTPS test until managed certificate becomes Active.${NC}"
  echo "Final URL: $FINAL_WWWROOT"

fi

echo


echo -e "${BOLD_GREEN}Moodle installation and configuration completed.${NC}"

echo