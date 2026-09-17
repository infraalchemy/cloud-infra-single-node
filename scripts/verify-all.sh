#!/usr/bin/env bash

BOLD_CYAN='\033[1;36m'
NC='\033[0m'

BOLD_GREEN='\033[1;32m'
NC='\033[0m'

set -euo pipefail

echo -e "${BOLD_GREEN}=== Verify Full Moodle GKE Deployment ===${NC}"
echo

echo -e "${BOLD_CYAN}Verify cluster nodes:${NC}"
kubectl get nodes
echo

echo -e "${BOLD_CYAN}Verify that the Artifact Registry repository is accessible:${NC}"
gcloud artifacts repositories list \
  --project civic-champion-439320-a5 \
  --location northamerica-northeast2
echo

echo -e "${BOLD_CYAN}Verify the reserved static IP:${NC}"
gcloud compute addresses describe moodle-static-ip \
  --global \
  --format="value(address)"
echo

echo -e "${BOLD_CYAN}Verify that the RWX storage class is available:${NC}"
kubectl get storageclass
echo

echo -e "${BOLD_CYAN}Verify that the Filestore CSI driver pods are running successfully:${NC}"
kubectl get pods -n kube-system | grep filestore
echo

echo -e "${BOLD_CYAN}Verify the PersistentVolumeClaims:${NC}"
kubectl get pvc
echo

echo -e "${BOLD_CYAN}Verify the deployed PHP image:${NC}"
kubectl get deployment php \
  -o jsonpath="{.spec.template.spec.containers[0].image}"
echo
echo

echo -e "${BOLD_CYAN}Verify PHP Docker base image:${NC}"
grep "^FROM" docker/php/Dockerfile
echo

echo -e "${BOLD_CYAN}Verify the running PHP version:${NC}"
kubectl exec deployment/php -- php -v
echo

echo -e "${BOLD_CYAN}Verify the Moodle application and data directory permissions:${NC}"
kubectl exec deployment/php -- \
  sh -c 'ls -ld /var/www/html /moodledata'
echo

echo -e "${BOLD_CYAN}Verify the Moodle application files are present:${NC}"
kubectl exec deployment/php -- ls /var/www/html
echo

echo -e "${BOLD_CYAN}Verify the live Nginx Service configuration:${NC}"
kubectl get service nginx \
  -o jsonpath='{.metadata.annotations}{"\n"}'
echo

echo -e "${BOLD_CYAN}Verify the Nginx BackendConfig configuration:${NC}"
kubectl get backendconfig nginx-backend-config \
  -o yaml | grep -A 5 "healthCheck:"
echo

echo -e "${BOLD_CYAN}Verify workload deployment:${NC}"
kubectl get pods
kubectl get svc
kubectl get endpoints nginx
kubectl get pvc
echo

echo -e "${BOLD_CYAN}Verify the Ingress configuration:${NC}"
kubectl get ingress moodle-ingress \
  -o jsonpath='{.metadata.annotations}{"\n"}'
echo

echo -e "${BOLD_CYAN}Verify the Ingress external IP:${NC}"
kubectl get ingress moodle-ingress
echo

echo -e "${BOLD_CYAN}Verify routing through the Terraform static IP:${NC}"

DOMAIN="bordercolliechronicles.ca"
STATIC_IP=$(terraform -chdir=terraform/gcp-gke output -raw static_ip_address)

echo -e "${BOLD_CYAN}Static IP: ${STATIC_IP:${NC}"

curl -I \
  -H "Host: ${DOMAIN}" \
  "http://${STATIC_IP}"

echo
echo -e "${BOLD_GREEN}=== Verification Complete ===S${NC}"