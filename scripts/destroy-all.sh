#!/usr/bin/env bash

BOLD_CYAN='\033[1;36m'
NC='\033[0m'

BOLD_GREEN='\033[1;32m'
NC='\033[0m'



echo -e "${BOLD_GREEN}=== Destroy Full Moodle GKE Deployment ===${NC}"
echo

echo
echo -e "${BOLD_CYAN}1. Delete Kubernetes resources:${NC}"
echo

echo -e "${BOLD_CYAN}Delete Ingress and overlay resources:${NC}"
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/overlays/ | kubectl delete -f -
echo
echo -e "${BOLD_CYAN}Delete Nginx:${NC}"
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/nginx/ | kubectl delete -f -
echo
echo -e "${BOLD_CYAN}Delete PHP:${NC}"
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/php/ | kubectl delete -f -
echo
echo -e "${BOLD_CYAN}Delete MySQL:${NC}"
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/mysql/ | kubectl delete -f -
echo
echo -e "${BOLD_CYAN}Delete storage:${NC}"
kubectl kustomize --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/storage/ | kubectl delete -f -
echo


echo -e "${BOLD_CYAN}2. Destroy Terraform-managed GCP infrastructure:${NC}"
terraform -chdir=terraform/gcp-gke destroy
echo

echo
echo -e "${BOLD_GREEN}=== Verify Infrastructure Teardown ===:${NC}"
echo

echo -e "${BOLD_CYAN}3. Verify GKE cluster and nodes are removed:${NC}"
gcloud container clusters list \
  --project civic-champion-439320-a5
echo

echo -e "${BOLD_CYAN}4. Verify persistent disks are removed:${NC}"
gcloud compute disks list \
  --project civic-champion-439320-a5
echo

echo -e "${BOLD_CYAN}5. Verify Artifact Registry repository is removed:${NC}"
gcloud artifacts repositories list \
  --project civic-champion-439320-a5 \
  --location northamerica-northeast2
echo

echo -e "${BOLD_CYAN}6. Verify reserved static IP is released:${NC}"
gcloud compute addresses list \
  --global \
  --project civic-champion-439320-a5
echo

echo
echo -e "${BOLD_GREEN}=== Teardown Verification Complete ===:${NC}"











