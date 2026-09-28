#!/usr/bin/env bash

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_BLUE='\033[1;34m'
NC='\033[0m'

PROJECT_ID="civic-champion-439320-a5"
LOCATION="northamerica-northeast2"


set -euo pipefail

echo -e "${BOLD_GREEN}=== Verify Full Moodle GKE Deployment ===${NC}"
echo

echo "Verify cluster nodes:${NC}"
kubectl get nodes
echo


echo "Verify that the Artifact Registry repository is accessible:"
gcloud artifacts repositories list \
  --project civic-champion-439320-a5 \
  --location northamerica-northeast2
echo


echo "Verify the reserved static IP"
gcloud compute addresses describe moodle-static-ip \
  --global \
  --format="value(address)"
echo

echo "Verify that the RWX storage class is available:"
kubectl get storageclass
echo

echo "Verify that the Filestore CSI driver pods are running successfully:"
kubectl get pods -n kube-system | grep filestore
echo


echo "Verify the PersistentVolumeClaims:"
kubectl get pvc
echo

echo
echo -e "${BOLD_CYAN}Verify MySQL database persistence:${NC}"

DB_USER=$(kubectl get secret mysql-secret \
  -o jsonpath='{.data.mysql-user}' | base64 -d)

DB_PASS=$(kubectl get secret mysql-secret \
  -o jsonpath='{.data.moodleuser-password}' | base64 -d)

DB_NAME=$(kubectl get secret mysql-secret \
  -o jsonpath='{.data.mysql-database}' | base64 -d)

echo "Verify Moodle database exists before pod deletion..."

kubectl exec deployment/mysql -- \
  mysql \
    --protocol=TCP \
    -h 127.0.0.1 \
    -u"$DB_USER" \
    -p"$DB_PASS" \
    -e "SELECT COUNT(*) AS moodle_table_count
        FROM information_schema.tables
        WHERE table_schema='$DB_NAME';"

OLD_MYSQL_POD=$(kubectl get pods -l app=mysql \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting MySQL pod: ${OLD_MYSQL_POD}"
kubectl delete pod "$OLD_MYSQL_POD"

echo "Waiting for replacement MySQL pod..."
kubectl rollout status deployment/mysql --timeout=5m

NEW_MYSQL_POD=$(kubectl get pods -l app=mysql \
  -o jsonpath='{.items[0].metadata.name}')

echo "Old MySQL pod: ${OLD_MYSQL_POD}"
echo "New MySQL pod: ${NEW_MYSQL_POD}"

echo
echo "Waiting for MySQL to accept connections..."

MYSQL_READY=false

for attempt in {1..24}; do
  if kubectl exec deployment/mysql -- \
    mysqladmin ping \
      --protocol=TCP \
      -h 127.0.0.1 \
      -u"$DB_USER" \
      -p"$DB_PASS" \
      --silent; then

    MYSQL_READY=true
    break
  fi

  echo "MySQL is not ready yet. Waiting 5 seconds... (${attempt}/24)"
  sleep 5
done

if [[ "$MYSQL_READY" != "true" ]]; then
  echo "ERROR: MySQL did not become ready within 2 minutes."
  exit 1
fi

echo -e "${BOLD_BLUE}MySQL is ready.${NC}"

echo
echo -e "${BOLD_CYAN}Verify Moodle database still exists after pod replacement:${NC}"

kubectl exec deployment/mysql -- \
  mysql \
    --protocol=TCP \
    -h 127.0.0.1 \
    -u"$DB_USER" \
    -p"$DB_PASS" \
    -e "SELECT COUNT(*) AS moodle_table_count
        FROM information_schema.tables
        WHERE table_schema='$DB_NAME';"

echo -e "${BOLD_CYAN}MySQL persistence verified.${NC}"
echo

echo "Verify the deployed PHP image:"
kubectl get deployment php \
  -o jsonpath="{.spec.template.spec.containers[0].image}"
echo

echo "Verify PHP Docker base image:"
grep "^FROM" docker/php/Dockerfile
echo

echo "Verify the running PHP version:"
kubectl exec deployment/php -- php -v
echo

echo "Verify the Moodle application and data directory permissions:"
MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- \
  sh -c 'ls -ld /var/www/html /moodledata'
echo


echo "Verify the Moodle application files are present:"
MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- sh -c \
  "ls -1 /var/www/html | awk '{printf \"%-25s\", \$0; if (NR % 3 == 0) printf \"\n\"} END {if (NR % 3 != 0) printf \"\n\"}'"
echo

echo "Verify the live Nginx Service configuration:"

echo "BackendConfig:"
kubectl get service nginx \
  -o jsonpath='{.metadata.annotations.cloud\.google\.com/backend-config}{"\n"}'

echo "NEG:"
kubectl get service nginx \
  -o jsonpath='{.metadata.annotations.cloud\.google\.com/neg}{"\n"}'
echo

echo "Verify the Nginx BackendConfig configuration:"
kubectl get backendconfig nginx-backend-config \
  -o yaml | grep -A 5 "healthCheck:"
echo


echo "Verify workload deployment:"
kubectl get pods
kubectl get svc
kubectl get endpoints nginx
kubectl get pvc
echo


echo "Verify the Ingress configuration"

echo "Backend health:"
kubectl get ingress moodle-ingress \
  -o jsonpath='{.metadata.annotations.ingress\.kubernetes\.io/backends}{"\n"}'

echo "Ingress class:"
kubectl get ingress moodle-ingress \
  -o jsonpath='{.metadata.annotations.kubernetes\.io/ingress\.class}{"\n"}'

echo
echo -e "${BOLD_CYAN}Verify routing through the permanent static IP:${NC}"

DOMAIN="bordercolliechronicles.ca"

STATIC_IP=$(gcloud compute addresses describe moodle-static-ip \
  --global \
  --project="$PROJECT_ID" \
  --format="value(address)")

echo
echo -e "${BOLD_CYAN}Static IP: ${STATIC_IP}${NC}"

curl -I \
  -H "Host: ${DOMAIN}" \
  "http://${STATIC_IP}"

echo

echo
echo -e "${BOLD_CYAN}Verify managed certificate exists and name${NC}"
echo "Managed certificate:"
kubectl get ingress moodle-ingress \
  -o jsonpath='{.metadata.annotations.networking\.gke\.io/managed-certificates}{"\n"}'
echo

echo
echo -e "${BOLD_CYAN}Verify routing through the permanent static IP:${NC}"

DOMAIN="bordercolliechronicles.ca"

STATIC_IP=$(gcloud compute addresses describe moodle-static-ip \
  --global \
  --project="$PROJECT_ID" \
  --format="value(address)")

echo
echo -e "${BOLD_CYAN}Static IP: ${STATIC_IP}${NC}"

curl -I \
  -H "Host: ${DOMAIN}" \
  "http://${STATIC_IP}"

echo

echo
echo -e "${BOLD_CYAN}Verifying no custom Compute Engine images remain...${NC}"

CUSTOM_IMAGES=$(gcloud compute images list \
  --project="$PROJECT_ID" \
  --no-standard-images \
  --format="value(name)")

if [[ -z "$CUSTOM_IMAGES" ]]; then
  echo -e "${BOLD_GREEN}No custom Compute Engine images remain.${NC}"
else
  echo -e "${BOLD_BLUE}WARNING: Custom Compute Engine images still exist:${NC}"
  echo "$CUSTOM_IMAGES"
fi

echo


echo -e "${BOLD_CYAN}Verifying Artifact Registry repository was removed...${NC}"

if gcloud artifacts repositories describe moodle-repo \
  --location="$LOCATION" \
  --project="$PROJECT_ID" \
  > /dev/null 2>&1; then

  echo -e "${BOLD_RED}WARNING: Artifact Registry repository moodle-repo still exists.${NC}"

else

  echo -e "${BOLD_BLUE}Artifact Registry repository moodle-repo has been removed.${NC}"

fi

echo

echo -e "${BOLD_GREEN}=== Verification Complete ===${NC}"