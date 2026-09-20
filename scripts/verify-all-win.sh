#!/usr/bin/env bash

BOLD_CYAN='\033[1;36m'
NC='\033[0m'

BOLD_GREEN='\033[1;32m'
NC='\033[0m'


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

echo "Verify Moodle database exists before pod deletion..."
kubectl exec deployment/mysql -- mysql \
  -u root \
  -p"$(kubectl get secret mysql-secret -o jsonpath='{.data.root-password}' | base64 -d)" \
  -e "SHOW DATABASES;"

OLD_MYSQL_POD=$(kubectl get pods -l app=mysql \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting MySQL pod: ${OLD_MYSQL_POD}"
kubectl delete pod "$OLD_MYSQL_POD"

echo "Waiting for replacement MySQL pod..."
kubectl rollout status deployment/mysql --timeout=3m

NEW_MYSQL_POD=$(kubectl get pods -l app=mysql \
  -o jsonpath='{.items[0].metadata.name}')

echo "Old MySQL pod: ${OLD_MYSQL_POD}"
echo "New MySQL pod: ${NEW_MYSQL_POD}"

echo -e "${BOLD_CYAN}Verify Moodle database still exists...:${NC}"
kubectl exec deployment/mysql -- mysql \
  -u root \
  -p"$(kubectl get secret mysql-secret -o jsonpath='{.data.root-password}' | base64 -d)" \
  -e "SHOW DATABASES;"
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

echo
echo -e "${BOLD_CYAN}Verify PHP persistence:${NC}"

OLD_PHP_POD=$(kubectl get pods -l app=php \
  -o jsonpath='{.items[0].metadata.name}')

echo "Deleting PHP pod: ${OLD_PHP_POD}"
kubectl delete pod "$OLD_PHP_POD"

echo "Waiting for replacement PHP pod..."
kubectl rollout status deployment/php --timeout=30m

NEW_PHP_POD=$(kubectl get pods -l app=php \
  -o jsonpath='{.items[0].metadata.name}')

echo "Old PHP pod: ${OLD_PHP_POD}"
echo "New PHP pod: ${NEW_PHP_POD}"

echo "Verify Moodle application files survived pod replacement..."
MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- ls -l /var/www/html/config.php

echo "Verify Moodle data survived pod replacement..."
MSYS_NO_PATHCONV=1 kubectl exec deployment/php -- ls -la /moodledata | head
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

echo "Static IP:"
kubectl get ingress moodle-ingress \
  -o jsonpath='{.metadata.annotations.kubernetes\.io/ingress\.global-static-ip-name}{"\n"}'

echo "Managed certificate:"
kubectl get ingress moodle-ingress \
  -o jsonpath='{.metadata.annotations.networking\.gke\.io/managed-certificates}{"\n"}'
echo

echo "Verify the Ingress external IP:"
kubectl get ingress moodle-ingress
echo

echo "Verify routing through the Terraform static IP:"
DOMAIN="bordercolliechronicles.ca"
STATIC_IP=$(terraform -chdir=terraform/gcp-gke output -raw static_ip_address)
echo "Static IP: ${STATIC_IP}"
curl -I \
  -H "Host: ${DOMAIN}" \
  "http://${STATIC_IP}"
echo

echo -e "${BOLD_GREEN}=== Verification Complete ===${NC}"