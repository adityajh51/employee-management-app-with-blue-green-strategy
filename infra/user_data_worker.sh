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
