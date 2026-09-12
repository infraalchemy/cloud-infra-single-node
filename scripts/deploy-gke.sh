#!/usr/bin/env bash

set -euo pipefail

echo "=== Moodle GKE Deployment ==="
echo

echo "1. Deploying storage..."

# Relax Kustomize restrictions because the storage Kustomization references files outside its directory
kubectl kustomize \
  --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/storage/ | kubectl apply -f -

kubectl wait \
  --for=jsonpath='{.status.phase}'=Bound \
  pvc/moodledata-pvc \
  --timeout=2m

echo "Checking storage..."
kubectl get pvc

echo "Storage deployment finished."


echo "1. Deploying MySQL..."

# Relax Kustomize restrictions because the MySQL Kustomization references files outside its directory
kubectl kustomize \
  --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/mysql/ | kubectl apply -f -

echo "Waiting for MySQL..."

kubectl rollout status deployment/mysql --timeout=3m

echo "Checking MySQL..."
kubectl get pods -l app=mysql

echo "MySQL deployment finished."


echo "1. Deploying PHP..."

# Relax Kustomize restrictions because the PHP Kustomization references files outside its directory
kubectl kustomize \
  --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/php/ | kubectl apply -f -

echo "Waiting for PHP..."

kubectl rollout status deployment/php --timeout=20m

echo "Checking PHP..."
kubectl get pods -l app=php

echo "PHP deployment finished."


echo "1. Deploying Nginx..."

# Relax Kustomize restrictions because the Nginx Kustomization references files outside its directory
kubectl kustomize \
  --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/nginx/ | kubectl apply -f -

echo "Waiting for Nginx..."

kubectl rollout status deployment/nginx --timeout=5m

echo "Checking nginx..."
kubectl get pods -l app=nginx

echo "Nginx deployment finished."


# Relax Kustomize restrictions because GKE Ingress Kustomization references files outside its directory
kubectl kustomize \
  --load-restrictor LoadRestrictionsNone \
  kubernetes/gcp-gke/overlays/ | kubectl apply -f -

echo "Waiting for GKE Ingress address..."

kubectl wait \
  --for=jsonpath='{.status.loadBalancer.ingress[0].ip}' \
  ingress/moodle-ingress \
  --timeout=10m

echo "Checking GKE Ingress..."
kubectl get ingress moodle-ingress

echo "GKE Ingress deployment finished."