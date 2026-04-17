#!/bin/bash
set -e

echo "Starting Docker deployment..."

# Update package list
sudo apt update

# Install Docker (required BEFORE docker-compose)
if ! command -v docker >/dev/null 2>&1; then
  sudo apt install -y docker.io
  sudo systemctl enable docker
  sudo systemctl start docker
fi

# Install Docker Compose if missing
if ! command -v docker-compose >/dev/null 2>&1; then
  sudo apt install -y docker-compose
fi

# Ensure current user can run docker without sudo (best effort)
if groups $USER | grep -q docker; then
  echo "User already in docker group"
else
  echo "Adding user to docker group (may require re-login to take effect)"
  sudo usermod -aG docker $USER
fi

# =========================
# CLONE / UPDATE REPO
# =========================

if [ ! -d "cloud-infra-single-node" ]; then
  git clone https://github.com/infraalchemy/cloud-infra-single-node.git
else
  echo "Repo already exists, pulling latest changes..."
  cd cloud-infra-single-node
  git checkout feature
  git pull
  cd ..
fi

# Enter docker directory
cd cloud-infra-single-node/docker

# =========================
# DEPLOY
# =========================

sudo docker-compose down || true
sudo docker-compose build --no-cache
sudo docker-compose up -d

# Show running containers
sudo docker ps

# =========================
# HEALTH CHECK
# =========================

if sudo docker ps --format '{{.Names}}' | grep -q '^docker_nginx_1$'; then
  sudo docker exec docker_nginx_1 curl -f http://localhost || exit 1
fi

echo "Deployment complete."
