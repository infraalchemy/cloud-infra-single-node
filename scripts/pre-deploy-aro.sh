#!/usr/bin/env bash
set -euo pipefail
set +x  # Prevent shell tracing of credentials

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_BLUE='\033[1;34m'
NC='\033[0m'


ARO_CLUSTER="moodle-aro-cluster"
ARO_RESOURCE_GROUP="rg-moodle-aro"
ARO_API_URL="https://api.moodle-aro.centralus.aroapp.io:6443"
ARO_NAMESPACE="moodle"


echo -e "${BOLD_GREEN}=== Step 1: Validate Moodle Passwords ===${NC}"

: "${MYSQL_ROOT_PASSWORD:?MySQL root password is missing}"
echo -e "${BOLD_BLUE}PASS: MySQL root password is available${NC}"

: "${MOODLE_DB_PASSWORD:?Moodle database password is missing}"
echo -e "${BOLD_BLUE}PASS: Moodle database password is available${NC}"

: "${MOODLE_ADMIN_PASSWORD:?Moodle administrator password is missing}"
echo -e "${BOLD_BLUE}PASS: Moodle administrator password is available${NC}"

echo -e "${BOLD_GREEN}=== Step 2: Retrieve ARO Credentials ==={NC}"

ARO_USER=$(az aro list-credentials \
  --name "$ARO_CLUSTER" \
  --resource-group "$ARO_RESOURCE_GROUP" \
  --query kubeadminUsername -o tsv)

ARO_PASSWORD=$(az aro list-credentials \
  --name "$ARO_CLUSTER" \
  --resource-group "$ARO_RESOURCE_GROUP" \
  --query kubeadminPassword -o tsv)

: "${ARO_USER:?ARO username retrieval failed}"
echo -e "${BOLD_BLUE}PASS: ARO username retrieved${NC}"

: "${ARO_PASSWORD:?ARO password retrieval failed}"
echo -e "${BOLD_BLUE}PASS: ARO password retrieved${NC}"

echo -e "${BOLD_GREEN}=== Step 3: Login to ARO & Initialize Project ==={NC}"

oc login "$ARO_API_URL" \
  -u "$ARO_USER" \
  -p "$ARO_PASSWORD"

unset ARO_PASSWORD

oc whoami >/dev/null
echo -e "${BOLD_BLUE}PASS: OpenShift authentication successful{NC}"

# Create the project/namespace (OpenShift equivalent of a project scope)
if oc get project "$ARO_NAMESPACE" >/dev/null 2>&1; then
  echo "PASS: Project $ARO_NAMESPACE already exists"
  oc project "$ARO_NAMESPACE" >/dev/null
else
  oc new-project "$ARO_NAMESPACE"
  echo -e "${BOLD_BLUE}PASS: Created and switched to project $ARO_NAMESPACE{NC}"
fi

echo -e "${BOLD_GREEN}=== Step 4: Create MySQL Secret ==={NC}"

oc create secret generic mysql-secret \
  --from-literal=root-password="$MYSQL_ROOT_PASSWORD" \
  --from-literal=moodleuser-password="$MOODLE_DB_PASSWORD" \
  --dry-run=client -o yaml | oc apply -n "$ARO_NAMESPACE" -f -

echo -e "${BOLD_GREEN}=== Step 5: Create PHP Secret ==={NC}"

oc create secret generic php-secret \
  --from-literal=moodleuser-password="$MOODLE_DB_PASSWORD" \
  --dry-run=client -o yaml | oc apply -n "$ARO_NAMESPACE" -f -

echo -e "${BOLD_GREEN}=== Step 6: Verify Kubernetes Secrets ==={NC}"

for secret in mysql-secret php-secret; do
  oc get secret "$secret" -n "$ARO_NAMESPACE" -o name >/dev/null
  echo -e "${BOLD_BLUE}PASS: $secret exists in $ARO_NAMESPACE{NC}"
done

for key in root-password moodleuser-password; do
  value=$(oc get secret mysql-secret -n "$ARO_NAMESPACE" \
    -o "go-template={{index .data \"$key\"}}")
  test -n "$value" || {
    echo -e "${BOLD_RED}FAIL: mysql-secret missing $key{NC}"
    exit 1
  }
  echo -e "${BOLD_BLUE}PASS: mysql-secret contains $key{NC}"
done

value=$(oc get secret php-secret -n "$ARO_NAMESPACE" \
  -o 'go-template={{index .data "moodleuser-password"}}')

test -n "$value" || {
  echo -e "${BOLD_RED}FAIL: php-secret missing moodleuser-password{NC}"
  exit 1
}

echo -e "${BOLD_BLUE}PASS: php-secret contains moodleuser-password{NC}"

echo
echo -e "${BOLD_BLUE}SUCCESS: ARO project initialization and Kubernetes Secrets verified.{NC}"