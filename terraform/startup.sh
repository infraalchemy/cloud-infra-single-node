
#!/bin/bash

set -e
exec > /var/log/startup.log 2>&1

echo "Starting setup..."

# Install dependencies
apt update
apt install -y docker.io docker-compose

systemctl enable docker
systemctl start docker

# Clone repo (always fresh for automation)
rm -rf cloud-infra-single-node
git clone https://github.com/infraalchemy/cloud-infra-single-node.git

cd cloud-infra-single-node/docker

# Deploy
docker-compose down || true
docker-compose build --no-cache
docker-compose up -d

docker ps
