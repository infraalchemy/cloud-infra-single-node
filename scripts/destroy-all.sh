#!/usr/bin/env bash

BOLD_CYAN='\033[1;36m'
BOLD_GREEN='\033[1;32m'
BOLD_BLUE='\033[1;34m'
NC='\033[0m'


# Define project variables needed for the Docker image path
PROJECT_ID="civic-champion-439320-a5"
LOCATION="northamerica-northeast2"


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

echo -e "${BOLD_CYAN}Wait for PersistentVolumes to be deleted:${NC}"

while kubectl get pv -o name | grep -q '^persistentvolume/pvc-'; do
  echo "Waiting for Kubernetes persistent volumes to be deleted..."
  sleep 10
done
echo

echo -e "${BOLD_BLUE}Persistent volumes deleted.${NC}"
echo

echo -e "${BOLD_CYAN}Waiting for GCP resources to finish releasing...${NC}"
sleep 30
echo

echo -e "${BOLD_CYAN}2. Destroy Terraform-managed GCP infrastructure:${NC}"

MAX_ATTEMPTS=3
RETRY_WAIT=60

for ATTEMPT in $(seq 1 "$MAX_ATTEMPTS"); do

  echo -e "${BOLD_BLUE}Terraform destroy attempt ${ATTEMPT}/${MAX_ATTEMPTS}...${NC}"

  if terraform -chdir=terraform/gcp-gke destroy \
    -var="project_id=${PROJECT_ID}" \
    -auto-approve; then

    echo -e "${BOLD_GREEN}Terraform destroy completed successfully.${NC}"
    break
  fi

  if [[ "$ATTEMPT" -eq "$MAX_ATTEMPTS" ]]; then
    echo "ERROR: Terraform destroy failed after ${MAX_ATTEMPTS} attempts."
    exit 1
  fi

  echo
  echo "GCP cleanup is still in progress."
  echo "Waiting ${RETRY_WAIT} seconds before retrying..."
  sleep "$RETRY_WAIT"
  echo

done

echo


echo
echo -e "${BOLD_GREEN}=== Verify Infrastructure Teardown ===:${NC}"
echo

echo
echo -e "${BOLD_CYAN}3. Verify GKE cluster and nodes are removed:${NC}"
gcloud container clusters list \
  --project "$PROJECT_ID"
echo

echo
echo -e "${BOLD_CYAN}4. Verify persistent disks are removed:${NC}"
gcloud compute disks list \
  --project "$PROJECT_ID"
echo

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
if [[ -z "$CUSTOM_IMAGES" ]]; then
  echo -e "${BOLD_GREEN}No custom Compute Engine images remain.${NC}"
else
  echo -e "${BOLD_BLUE}WARNING: Custom Compute Engine images still exist:${NC}"
  echo "$CUSTOM_IMAGES"
fi

echo

echo -e "${BOLD_CYAN}6. Verify reserved static IP is released:${NC}"
gcloud compute addresses list \
  --global \
  --project "$PROJECT_ID"
echo

echo
echo -e "${BOLD_GREEN}=== Teardown Verification Complete ===:${NC}"