#!/usr/bin/env bash

set -euo pipefail

# Define project variables needed for the Docker image path
PROJECT_ID="civic-champion-439320-a5"
REGION="northamerica-northeast2"

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_BLUE='\033[1;34m'
NC='\033[0m'


echo -e "${BOLD_GREEN}=== Moodle GKE Deployment ===${NC}"
echo

echo
echo -e "${BOLD_CYAN}Deploying storage...:${NC}"

# Relax Kustomize restrictions because the storage Kustomization references files outside its directory
kubectl kustomize \
  --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/storage/ | kubectl apply -f -

kubectl wait \
  --for=jsonpath='{.status.phase}'=Bound \
  pvc/moodledata-pvc \
  --timeout=2m
  
kubectl wait \
  --for=jsonpath='{.status.phase}'=Bound \
  pvc/mysql-pvc \
  --timeout=2m

echo -e "${BOLD_CYAN}Checking storage...${NC}"
kubectl get pvc

echo -e "${BOLD_BLUE}Storage deployment finished:${NC}"
echo

echo
echo -e "${BOLD_CYAN}Deploying MySQL...:${NC}"

# Relax Kustomize restrictions because the MySQL Kustomization references files outside its directory
kubectl kustomize \
  --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/mysql/ | kubectl apply -f -

echo "Waiting for MySQL..."

kubectl rollout status deployment/mysql --timeout=3m

echo "Checking MySQL..."
kubectl get pods -l app=mysql

echo -e "${BOLD_BLUE}MySQL deployment finished:${NC}"
echo

# ================================================================================
# BUILD & PUSH CUSTOM PHP IMAGE
# This happens after MySQL/Storage are running but BEFORE the PHP workload deploys
# ================================================================================
echo
echo -e "${BOLD_CYAN}Configuring Docker authentication...:${NC}"
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

echo
echo -e "${BOLD_CYAN}Building PHP image...:${NC}"
IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/moodle-repo/custom-php:8.2"

docker build --no-cache \
  -t "$IMAGE" \
  docker/php

echo -e "${BOLD_CYAN}Pushing PHP image...:${NC}"
docker push "$IMAGE"

echo -e "${BOLD_BLUE}PHP image built and pushed successfully:${NC}"

echo
echo -e "${BOLD_CYAN}Deploying PHP...:${NC}"

# Relax Kustomize restrictions because the PHP Kustomization references files outside its directory
kubectl kustomize \
  --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/php/ | kubectl apply -f -

echo "Waiting for PHP..."
kubectl rollout status deployment/php --timeout=30m

echo "Checking PHP..."
kubectl get pods -l app=php

echo -e "${BOLD_BLUE}PHP deployment finished:${NC}"

echo
echo -e "${BOLD_CYAN}Deploying Nginx...${NC}"

# Relax Kustomize restrictions because the Nginx Kustomization references files outside its directory
kubectl kustomize \
  --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/nginx/ | kubectl apply -f -

echo "Waiting for Nginx..."
kubectl rollout status deployment/nginx --timeout=5m

echo

echo "Checking nginx..."
kubectl get pods -l app=nginx

echo -e "${BOLD_BLUE}Nginx deployment finished:${NC}"

echo
echo -e "${BOLD_CYAN}Deploying GKE Ingress:${NC}"
# Relax Kustomize restrictions because GKE Ingress Kustomization references files outside its directory
kubectl kustomize \
  --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/overlays/ | kubectl apply -f -

echo

echo "Waiting for GKE Ingress address..."

kubectl wait \
  --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' \
  ingress/moodle-ingress \
  --timeout=10m

echo "Checking GKE Ingress..."
kubectl get ingress moodle-ingress

echo -e "${BOLD_BLUE}GKE Ingress deployment finished:${NC}"

echo
echo -e "${BOLD_GREEN}=== Moodle GKE Deployment ===${NC}"