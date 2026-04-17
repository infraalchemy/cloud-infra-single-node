
#!/bin/bash
exec > /var/log/startup-script.log 2>&1

sudo apt update
sudo apt install -y docker-compose
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
