#!/bin/bash
set -e

MANAGER_IP=$1
NEW_VERSION=$2
TARGET=$3   # blue or green

if [ -z "$TARGET" ]; then
  echo "❌ No target color specified. Exiting."
  exit 1
fi

# Determine opposite color
if [ "$TARGET" == "blue" ]; then
  CURRENT="green"
  HEALTH_PORT=8080   # Blue frontend port
else
  CURRENT="blue"
  HEALTH_PORT=8082   # Green frontend port
fi

echo "➡️ Deploying to $TARGET stack..."

# Copy stack file to manager
scp -o StrictHostKeyChecking=no docker-stack-${TARGET}.yml ec2-user@$MANAGER_IP:/home/ec2-user/

# Update image versions
ssh ec2-user@$MANAGER_IP \
  "sed -i 's|backend-app:.*|backend-app:${NEW_VERSION}|' /home/ec2-user/docker-stack-${TARGET}.yml"
ssh ec2-user@$MANAGER_IP \
  "sed -i 's|frontend-app:.*|frontend-app:${NEW_VERSION}|' /home/ec2-user/docker-stack-${TARGET}.yml"

# Deploy target stack
ssh ec2-user@$MANAGER_IP \
  "docker stack deploy -c /home/ec2-user/docker-stack-${TARGET}.yml empapp_${TARGET}"

# Wait for services to stabilize
echo "⏳ Waiting for services to stabilize..."
sleep 60

# Health check
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://$MANAGER_IP:$HEALTH_PORT)

if [ "$HEALTH" == "200" ]; then
  echo "✅ New version healthy. Removing old ${CURRENT} stack..."
  ssh ec2-user@$MANAGER_IP "docker stack rm empapp_${CURRENT} || true"
else
  echo "❌ Health check failed. Rolling back."
  ssh ec2-user@$MANAGER_IP "docker stack rm empapp_${TARGET}"
  exit 1
fi
