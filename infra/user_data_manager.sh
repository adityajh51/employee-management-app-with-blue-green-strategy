#!/bin/bash
set -eux

# Update system
yum update -y

# Install Docker
amazon-linux-extras enable docker
yum install -y docker

# Start and enable Docker
systemctl enable docker
systemctl start docker

# Add default user to Docker group
usermod -aG docker ec2-user

# Initialize swarm
MANAGER_IP=$(hostname -I | awk '{print $1}')
docker swarm init --advertise-addr ${MANAGER_IP}

# Save worker join token so workers can fetch it later if needed
docker swarm join-token -q worker > /home/ec2-user/worker_token
chmod 644 /home/ec2-user/worker_token
