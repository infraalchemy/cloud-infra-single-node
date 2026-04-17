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

# Go to project directory
cd ~/cloud-infra-single-node/docker

# Stop existing containers
sudo docker-compose down || true

# Rebuild images without cache
sudo docker-compose build --no-cache

# Start containers in detached mode
sudo docker-compose up -d

# Show running containers
sudo docker ps

# Optional health test for nginx container
if sudo docker ps --format '{{.Names}}' | grep -q '^docker_nginx_1$'; then
  sudo docker exec docker_nginx_1 curl -f http://localhost || exit 1
fi

echo "Deployment complete."
