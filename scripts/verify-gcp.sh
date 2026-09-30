#!/usr/bin/env bash

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_BLUE='\033[1;34m'
NC='\033[0m'

# Define project variables needed for the Docker image path
PROJECT_ID="civic-champion-439320-a5"
LOCATION="northamerica-northeast2"


set -euo pipefail

echo
echo -e "${BOLD_GREEN}=== Verify Full Moodle GKE Deployment ===${NC}"
echo

echo -e "${BOLD_CYAN}Verify cluster nodes:${NC}"
kubectl get nodes
echo

echo -e "${BOLD_CYAN}Verify that the Artifact Registry repository is accessible:${NC}"
gcloud artifacts repositories list \
  --project "$PROJECT_ID" \
  --location "$LOCATION"
echo

echo -e "${BOLD_CYAN}Verify the reserved static IP:${NC}"
gcloud compute addresses describe moodle-static-ip \
  --global \
  --format="value(address)"
echo

echo
echo -e "${BOLD_CYAN}Verify that the RWX storage class is available:${NC}"
kubectl get storageclass
echo

echo
echo -e "${BOLD_CYAN}Verify that the Filestore CSI driver pods are running successfully:${NC}"
kubectl get pods -n kube-system | grep filestore
echo

echo
echo -e "${BOLD_CYAN}Verify the PersistentVolumeClaims:${NC}"
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

echo -e "${BOLD_BLUE}Old MySQL pod: ${OLD_MYSQL_POD}${NC}"
echo -e "${BOLD_BLUE}New MySQL pod: ${NEW_MYSQL_POD}${NC}"

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

echo -e "${BOLD_GREEN}MySQL is ready.${NC}"

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

echo -e "${BOLD_GREEN}MySQL persistence verified.${NC}"
echo
echo
echo -e "${BOLD_CYAN}Verify the deployed PHP image:${NC}"
kubectl get deployment php \
  -o jsonpath="{.spec.template.spec.containers[0].image}"
echo
echo

echo -e "${BOLD_CYAN}Verify the running PHP version:${NC}"
kubectl exec deployment/php -- php -v
echo

echo -e "${BOLD_CYAN}Verify the Moodle application and data directory permissions:${NC}"
kubectl exec deployment/php -- \
  sh -c 'ls -ld /var/www/html /moodledata'
echo

echo
echo -e "${BOLD_CYAN}Verify the Moodle application files are present:${NC}"
kubectl exec deployment/php -- sh -c \
  "ls -1 /var/www/html | awk '{printf \"%-25s\", \$0; if (NR % 3 == 0) printf \"\n\"} END {if (NR % 3 != 0) printf \"\n\"}'"
echo


echo
echo -e "${BOLD_CYAN}Verify the live Nginx Service configuration:${NC}"
echo "BackendConfig:"
kubectl get service nginx \
  -o jsonpath='{.metadata.annotations.cloud\.google\.com/backend-config}{"\n"}'
echo

echo "NEG:"
kubectl get service nginx \
  -o jsonpath='{.metadata.annotations.cloud\.google\.com/neg}{"\n"}'
echo

echo "Verify the Nginx BackendConfig configuration:"
kubectl get backendconfig nginx-backend-config \
  -o yaml | grep -A 5 "healthCheck:"
echo

echo
echo -e "${BOLD_CYAN}Verify workload deployment:${NC}"
kubectl get pods
kubectl get svc
kubectl get endpoints nginx
kubectl get pvc
echo

echo
echo -e "${BOLD_CYAN}Verify the Ingress configuration:${NC}"
kubectl get ingress moodle-ingress \
  -o jsonpath='{.metadata.annotations}{"\n"}'
echo

echo
echo -e "${BOLD_CYAN}Verify the Ingress external IP:${NC}"
kubectl get ingress moodle-ingress \
  -o jsonpath='{.metadata.annotations.kubernetes\.io/ingress\.class}{"\n"}'
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

  echo -e "${BOLD_BLUE}WARNING: Artifact Registry repository moodle-repo still exists.${NC}"

else

  echo -e "${BOLD_GREEN}Artifact Registry repository moodle-repo has been removed.${NC}"

fi

echo



echo
echo -e "${BOLD_GREEN}=== Verification Complete ===${NC}"