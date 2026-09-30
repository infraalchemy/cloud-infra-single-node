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
# ADDED TEST 1: VERIFY INIT CONTAINER OPERATION & HISTORY
# =====================================================================
echo -e "${BOLD_CYAN}Verify Init Container Success Status:${NC}"
INIT_STATUS=$(oc get pod -l app=moodle-php -o jsonpath='{.items[0].status.initContainerStatuses[0].state.terminated.exitCode}' 2>/dev/null || echo "not_found")

if [ "$INIT_STATUS" = "0" ]; then
    echo -e "${BOLD_GREEN}✓ Init container executed and exited successfully (Exit Code 0).${NC}"
elif [ "$INIT_STATUS" = "not_found" ]; then
    echo -e "${BOLD_YELLOW}⚠ Could not find init container status. Check if deployment is still rolling.${NC}"
else
    echo -e "${BOLD_RED}✗ ERROR: Init container failed with Exit Code: ${INIT_STATUS}${NC}"
    echo "Showing last 20 lines of Init Container logs:"
    oc logs deployment/moodle-php -c moodle-init --tail=20
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
oc exec deployment/moodle-mysql -- \
  mysql --protocol=TCP -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" \
    -e "SELECT COUNT(*) AS moodle_table_count FROM information_schema.tables WHERE table_schema='$DB_NAME';"

OLD_MYSQL_POD=$(oc get pods -l app=moodle-mysql -o jsonpath='{.items[0].metadata.name}')
echo "Deleting MySQL pod: ${OLD_MYSQL_POD}"
oc delete pod "$OLD_MYSQL_POD"

echo "Waiting for replacement MySQL pod..."
oc rollout status deployment/moodle-mysql --timeout=5m

NEW_MYSQL_POD=$(oc get pods -l app=moodle-mysql -o jsonpath='{.items[0].metadata.name}')
echo -e "${BOLD_BLUE}Old MySQL pod: ${OLD_MYSQL_POD}${NC}"
echo -e "${BOLD_BLUE}New MySQL pod: ${NEW_MYSQL_POD}${NC}"
echo

echo "Waiting for MySQL to accept connections..."
MYSQL_READY=false
for attempt in {1..24}; do
  if oc exec deployment/moodle-mysql -- mysqladmin ping --protocol=TCP -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" --silent; then
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
echo -e "${BOLD_GREEN}MySQL is ready.${NC}"
echo

echo -e "${BOLD_CYAN}Verify Moodle database still exists after pod replacement:${NC}"
oc exec deployment/moodle-mysql -- \
  mysql --protocol=TCP -h 127.0.0.1 -u"$DB_USER" -p"$DB_PASS" \
    -e "SELECT COUNT(*) AS moodle_table_count FROM information_schema.tables WHERE table_schema='$DB_NAME';"
echo -e "${BOLD_GREEN}MySQL persistence verified.${NC}"
echo

# =====================================================================
# PHP ENGINE TESTS
# =====================================================================
echo -e "${BOLD_CYAN}Verify the deployed PHP image stream track:${NC}"
oc get deployment moodle-php -o jsonpath="{.spec.template.spec.containers.image}"
echo
echo

echo -e "${BOLD_CYAN}Verify the running PHP version:${NC}"
oc exec deployment/moodle-php -c php-fpm -- php -v
echo

echo -e "${BOLD_CYAN}Verify the Moodle application and data directory permissions:${NC}"
oc exec deployment/moodle-php -c php-fpm -- sh -c 'ls -ld /var/www/html /var/www/moodledata'
echo

# =====================================================================
# ADDED TEST 2: WRITE PRIVILEGE CHECK FOR OPENSHIFT SECURITY (SCC)
# =====================================================================
echo -e "${BOLD_CYAN}Verify Pod Write Capabilities (Arbitrary User ID Mock Test):${NC}"
if oc exec deployment/moodle-php -c php-fpm -- sh -c 'touch /var/www/moodledata/test_write.txt && rm /var/www/moodledata/test_write.txt' 2>/dev/null; then
    echo -e "${BOLD_GREEN}✓ Success: Custom PHP image successfully bypassed OpenShift non-root storage locks.${NC}"
else
    echo -e "${BOLD_RED}✗ FAILURE: PHP Pod cannot write to /var/www/moodledata. Permissions/Ownership mismatch.${NC}"
fi
echo

echo -e "${BOLD_CYAN}Verify the Moodle application files are present:${NC}"
oc exec deployment/moodle-php -c php-fpm -- sh -c \
  "ls -1 /var/www/html | awk '{printf \"%-25s\", \$0; if (NR % 3 == 0) printf \"\n\"} END {if (NR % 3 != 0) printf \"\n\"}'"
echo

# =====================================================================
# ADDED TEST 3: ISOLATED POD INTERNAL FastCGI NETWORKING CHECK
# =====================================================================
echo -e "${BOLD_CYAN}Verify Internal FastCGI Network Route (Nginx -> PHP Pod):${NC}"
# Since your Nginx container is separated, this logs directly into the Nginx pod
# and runs a standard tcp check to make sure it can bridge to the PHP network service port
if oc exec deployment/moodle-nginx -- sh -c 'nc -z -w3 php-service 9000' 2>/dev/null; then
    echo -e "${BOLD_GREEN}✓ Success: Nginx pod successfully reached PHP engine on php-service:9000${NC}"
else
    echo -e "${BOLD_RED}✗ FAILURE: Nginx pod cannot reach the PHP container over the cluster network.${NC}"
fi
echo

# =====================================================================
# ROUTE AND PUBLIC TRAFFIC CHECK
# =====================================================================
echo -e "${BOLD_CYAN}Verify workload infrastructure statuses:${NC}"
oc get pods
oc get svc
oc get endpoints nginx-service
echo

echo -e "${BOLD_CYAN}Verify the OpenShift Edge Route (Replacing GKE Ingress):${NC}"
oc get route moodle-public-route -o yaml | grep -A 5 "tls:"
echo

echo -e "${BOLD_CYAN}Verify routing through the auto-generated Sandbox Domain:${NC}"
ROUTE_HOST=$(oc get route moodle-public-route -o jsonpath='{.spec.host}')
echo -e "${BOLD_CYAN}Target Endpoint Host: ${ROUTE_HOST}${NC}"

# Hits the OpenShift edge router directly
curl -I "https://${ROUTE_HOST}"
echo

echo -e "${BOLD_GREEN}=== OpenShift Verification Complete ===${NC}"
