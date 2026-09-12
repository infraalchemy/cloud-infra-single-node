#!/usr/bin/env bash

set -euo pipefail

PROJECT_ID="civic-champion-439320-a5"
REGION="northamerica-northeast2"

echo "=== Full Moodle GKE Deployment ==="
echo

echo "1. Provisioning GCP infrastructure..."
terraform -chdir=terraform/gcp-gke init
terraform -chdir=terraform/gcp-gke apply \
  -var="project_id=${PROJECT_ID}" \
  -auto-approve
  
echo
echo "GKE infrastructure ready."

echo
echo "2. Connecting kubectl to GKE..."

CLUSTER_NAME=$(terraform -chdir=terraform/gcp-gke output -raw cluster_name)
CLUSTER_LOCATION=$(terraform -chdir=terraform/gcp-gke output -raw cluster_location)

gcloud container clusters get-credentials "$CLUSTER_NAME" \
  --zone "$CLUSTER_LOCATION" \
  --project "$PROJECT_ID"

echo


echo "3. Configuring Docker authentication..."

gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

echo
echo "4. Building PHP image..."

IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/moodle-repo/custom-php:8.2"

docker build \
  -t "$IMAGE" \
  docker/php

echo
echo "5. Pushing PHP image..."

docker push "$IMAGE"

echo

echo "PHP image built and pushed."

