#!/bin/bash
set -e
exec > /var/log/startup.log 2>&1

echo "Starting setup..."

# Install dependencies
sudo apt update
sudo apt install -y docker.io docker-compose git

sudo systemctl enable docker
sudo systemctl start docker

# Use known directory
cd /opt

# Fresh clone
rm -rf cloud-infra-single-node
git clone https://github.com/infraalchemy/cloud-infra-single-node.git

cd /opt/cloud-infra-single-node/docker


# Deploy
sudo docker-compose down || true
sudo docker-compose build --no-cache
sudo docker-compose up -d

sudo docker ps
