#!/usr/bin/env bash

# Color codes
BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_YELLOW='\033[1;33m'
BOLD_BLUE='\033[1;34m'
BOLD_RED='\033[1;31m'
NC='\033[0m'

# OpenShift namespaces map directly to your sandbox/project name
NAMESPACE=$(oc project -q)

set -euo pipefail

echo
echo -e "${BOLD_GREEN}=== Verify Full Moodle OpenShift Deployment ===${NC}"
echo

echo -e "${BOLD_CYAN}Verify active project context:${NC}"
echo "Current OpenShift Project: ${NAMESPACE}"
echo

echo -e "${BOLD_CYAN}Verify local ImageStreams are present:${NC}"
oc get imagestreams
echo

echo -e "${BOLD_CYAN}Verify that the storage classes are available:${NC}"
oc get storageclass
echo

echo -e "${BOLD_CYAN}Verify the PersistentVolumeClaims (RWO & RWX):${NC}"
oc get pvc
echo

# =====================================================================
# VERIFY PHP INIT CONTAINER COMPLETED SUCCESSFULLY
# =====================================================================
echo
echo -e "${BOLD_CYAN}Verify Init Container Success Status:${NC}"

# Wait for the PHP deployment to finish rolling out.
if ! oc rollout status deployment/php --timeout=5m; then
    echo -e "${BOLD_RED}✗ ERROR: PHP deployment did not become ready.${NC}"
    oc get pods -l app=php
    exit 1
fi

# Get the pod currently owned by the PHP deployment.
PHP_POD=$(oc get pods -l app=php \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [[ -z "$PHP_POD" ]]; then
    echo -e "${BOLD_RED}✗ ERROR: No running PHP pod found.${NC}"
    oc get pods -l app=php
    exit 1
fi

echo "PHP pod: $PHP_POD"

# Make sure the expected init container exists.
INIT_NAME=$(oc get pod "$PHP_POD" \
    -o jsonpath='{.status.initContainerStatuses[?(@.name=="init-moodle")].name}' \
    2>/dev/null || true)

if [[ "$INIT_NAME" != "init-moodle" ]]; then
    echo -e "${BOLD_RED}✗ ERROR: init-moodle status was not found.${NC}"
    oc describe pod "$PHP_POD"
    exit 1
fi

# Read the completed init container's state.
INIT_EXIT_CODE=$(oc get pod "$PHP_POD" \
    -o jsonpath='{.status.initContainerStatuses[?(@.name=="init-moodle")].state.terminated.exitCode}' \
    2>/dev/null || true)

INIT_REASON=$(oc get pod "$PHP_POD" \
    -o jsonpath='{.status.initContainerStatuses[?(@.name=="init-moodle")].state.terminated.reason}' \
    2>/dev/null || true)

if [[ "$INIT_EXIT_CODE" == "0" && "$INIT_REASON" == "Completed" ]]; then

    echo -e "${BOLD_BLUE}✓ init-moodle completed successfully.${NC}"
    echo "  Exit Code: $INIT_EXIT_CODE"
    echo "  Reason:    $INIT_REASON"

else

    echo -e "${BOLD_RED}✗ ERROR: init-moodle did not complete successfully.${NC}"
    echo "  Exit Code: ${INIT_EXIT_CODE:-Unavailable}"
    echo "  Reason:    ${INIT_REASON:-Unavailable}"

    echo
    echo "Init container status:"
    oc get pod "$PHP_POD" \
        -o jsonpath='{.status.initContainerStatuses[?(@.name=="init-moodle")]}' \
        || true

    echo
    echo
    echo "Last 20 lines of init-moodle logs:"
    oc logs "$PHP_POD" -c init-moodle --tail=20 || true

    exit 1
fi

echo

# =====================================================================
# DATABASE PERSISTENCE TESTS (Original logic preserved)
# =====================================================================
echo -e "${BOLD_CYAN}Verify MySQL database persistence:${NC}"

DB_USER=$(oc get secret mysql-secret -o jsonpath='{.data.mysql-user}' | base64 -d)
DB_PASS=$(oc get secret mysql-secret -o jsonpath='{.data.moodleuser-password}' | base64 -d)
DB_NAME=$(oc get secret mysql-secret -o jsonpath='{.data.mysql-database}' | base64 -d)

echo "Verify Moodle database exists before pod deletion..."
oc exec deployment/mysql -- \
  mysql --protocol=TCP -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" \
    -e "SELECT COUNT(*) AS moodle_table_count FROM information_schema.tables WHERE table_schema='$DB_NAME';"

OLD_MYSQL_POD=$(oc get pods -l app=mysql -o jsonpath='{.items[0].metadata.name}')
echo "Deleting MySQL pod: ${OLD_MYSQL_POD}"
oc delete pod "$OLD_MYSQL_POD"

echo "Waiting for replacement MySQL pod..."
oc rollout status deployment/mysql --timeout=5m

NEW_MYSQL_POD=$(oc get pods -l app=mysql -o jsonpath='{.items[0].metadata.name}')
echo -e "${BOLD_BLUE}Old MySQL pod: ${OLD_MYSQL_POD}${NC}"
echo -e "${BOLD_BLUE}New MySQL pod: ${NEW_MYSQL_POD}${NC}"
echo

echo "Waiting for MySQL to accept connections..."
MYSQL_READY=false
for attempt in {1..24}; do
  if oc exec deployment/mysql -- mysqladmin ping --protocol=TCP -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" --silent; then
    MYSQL_READY=true
    break
  fi
  echo "MySQL is not ready yet. Waiting 5 seconds... (${attempt}/24)"
  sleep 5
done

if [[ "$MYSQL_READY" != "true" ]]; then
  echo -e "${BOLD_RED}ERROR: MySQL did not become ready within 2 minutes.${NC}"
  exit 1
fi
echo -e "${BOLD_BLUE}MySQL is ready.${NC}"
echo

echo -e "${BOLD_CYAN}Verify Moodle database still exists after pod replacement:${NC}"
oc exec deployment/mysql -- \
  mysql --protocol=TCP -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" \
    -e "SELECT COUNT(*) AS moodle_table_count FROM information_schema.tables WHERE table_schema='$DB_NAME';"
echo -e "${BOLD_BLUE}MySQL persistence verified.${NC}"
echo

# =====================================================================
# PHP ENGINE TESTS
# =====================================================================
echo -e "${BOLD_CYAN}Verify the PHP image used by the Deployment:${NC}"
oc get deployment php \
  -o jsonpath='{.spec.template.spec.containers[?(@.name=="php")].image}'
echo

echo -e "${BOLD_CYAN}Verify the running PHP version:${NC}"
oc exec deployment/php -c php -- php -v
echo

echo -e "${BOLD_CYAN}Verify the Moodle application and data directory permissions:${NC}"
oc exec deployment/php -c php -- sh -c 'ls -ld /var/www/html /moodledata'
echo

# =====================================================================
# ADDED TEST 2: WRITE PRIVILEGE CHECK FOR OPENSHIFT SECURITY (SCC)
# =====================================================================
echo -e "${BOLD_CYAN}Verify Pod Write Capabilities (Arbitrary User ID Mock Test):${NC}"
if oc exec deployment/php -c php -- sh -c 'touch /moodledata/test_write.txt && rm /moodledata/test_write.txt' 2>/dev/null; then
    echo -e "${BOLD_BLUE}✓ Success: PHP container can write to moodledata while running under OpenShift restricted security.${NC}"
else
    echo -e "${BOLD_RED}✗ FAILURE: PHP Pod cannot write to /moodledata. Permissions/Ownership mismatch.${NC}"
fi
echo

echo -e "${BOLD_CYAN}Verify the Moodle application files are present:${NC}"
oc exec deployment/php -c php -- sh -c \
  "ls -1 /var/www/html | awk '{printf \"%-25s\", \$0; if (NR % 3 == 0) printf \"\n\"} END {if (NR % 3 != 0) printf \"\n\"}'"
echo

# =====================================================================
# ADDED TEST 3: ISOLATED POD INTERNAL FastCGI NETWORKING CHECK
# =====================================================================
echo -e "${BOLD_CYAN}Verify PHP Service and FastCGI endpoint:${NC}"

oc get service php

PHP_PORT=$(oc get service php \
  -o jsonpath='{.spec.ports[0].port}')

PHP_ENDPOINT=$(oc get endpointslice \
  -l kubernetes.io/service-name=php \
  -o jsonpath='{.items[0].endpoints[0].addresses[0]}')

PHP_ENDPOINT_PORT=$(oc get endpointslice \
  -l kubernetes.io/service-name=php \
  -o jsonpath='{.items[0].ports[0].port}')

if [[ "$PHP_PORT" == "9000" && \
      "$PHP_ENDPOINT_PORT" == "9000" && \
      -n "$PHP_ENDPOINT" ]]; then

    echo -e "${BOLD_GREEN}✓ PHP Service has an active FastCGI endpoint on port 9000.${NC}"
    echo "  Service:  php:${PHP_PORT}"
    echo "  Endpoint: ${PHP_ENDPOINT}:${PHP_ENDPOINT_PORT}"

else
    echo -e "${BOLD_RED}✗ FAILURE: PHP Service/EndpointSlice is not correctly configured for FastCGI.${NC}"
    exit 1
fi

echo
# =====================================================================
# ROUTE AND PUBLIC TRAFFIC CHECK
# =====================================================================
echo -e "${BOLD_CYAN}Verify workload infrastructure statuses:${NC}"
oc get pods
oc get svc
oc get endpoints
echo

echo -e "${BOLD_CYAN}Verify the OpenShift Edge Route (Replacing GKE Ingress):${NC}"
oc get route moodle -o yaml | grep -A 5 "tls:"
echo

echo -e "${BOLD_CYAN}Verify routing through the auto-generated Sandbox Domain:${NC}"
ROUTE_HOST=$(oc get route moodle -o jsonpath='{.spec.host}')
echo -e "${BOLD_CYAN}Target Endpoint Host: ${ROUTE_HOST}${NC}"

# Hits the OpenShift edge router directly
curl -I "https://${ROUTE_HOST}"
echo

echo -e "${BOLD_GREEN}=== OpenShift Verification Complete ===${NC}"
