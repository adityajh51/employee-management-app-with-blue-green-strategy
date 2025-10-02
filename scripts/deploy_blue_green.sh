#!/bin/bash
set -e

MANAGER_IP=$1
NEW_VERSION=$2
BLUE_STACK="empapp_blue"
GREEN_STACK="empapp_green"

# Detect currently active stack
ACTIVE_STACK=$(ssh -o StrictHostKeyChecking=no ec2-user@$MANAGER_IP \
  "docker service ls --format '{{.Name}}' | grep ${BLUE_STACK}_frontend || true")

if [ -n "$ACTIVE_STACK" ]; then
  CURRENT="blue"
  TARGET="green"
else
  CURRENT="green"
  TARGET="blue"
fi

echo "Current active stack: $CURRENT"
echo "Deploying new version to $TARGET stack"

# Copy appropriate stack file to manager
scp -o StrictHostKeyChecking=no docker-stack-${TARGET}.yml ec2-user@$MANAGER_IP:/home/ec2-user/

# Update stack file dynamically with new image tags
ssh ec2-user@$MANAGER_IP \
  "sed -i 's|backend-app:.*|backend-app:${NEW_VERSION}|' /home/ec2-user/docker-stack-${TARGET}.yml"
ssh ec2-user@$MANAGER_IP \
  "sed -i 's|frontend-app:.*|frontend-app:${NEW_VERSION}|' /home/ec2-user/docker-stack-${TARGET}.yml"

# Deploy target stack
ssh ec2-user@$MANAGER_IP \
  "docker stack deploy -c /home/ec2-user/docker-stack-${TARGET}.yml empapp_${TARGET}"

# Health check
echo "Waiting for services to stabilize..."
sleep 60
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://$MANAGER_IP)

if [ "$HEALTH" == "200" ]; then
  echo "New version healthy, switching traffic"
  
  # Stop old stack
  ssh ec2-user@$MANAGER_IP "docker stack rm empapp_${CURRENT}"
else
  echo "New version failed health check, rolling back"
  ssh ec2-user@$MANAGER_IP "docker stack rm empapp_${TARGET}"
  exit 1
fi
