#!/bin/bash
set -e

MANAGER_IP=$1
NEW_VERSION=$2
TARGET=$3   # blue or green

if [ -z "$TARGET" ]; then
  echo "❌ No target specified. Exiting."
  exit 1
fi

# Determine current stack
if [ "$TARGET" == "blue" ]; then
  CURRENT="green"
else
  CURRENT="blue"
fi

# Set temporary frontend port for testing
if [ "$TARGET" == "green" ]; then
  TEST_FRONTEND_PORT=8082
else
  TEST_FRONTEND_PORT=8080
fi

echo "➡️ Deploying $TARGET stack for testing on port $TEST_FRONTEND_PORT..."

# Copy stack file to manager
scp docker-stack-${TARGET}.yml ec2-user@$MANAGER_IP:/home/ec2-user/

# Update backend/frontend images & frontend test port
ssh ec2-user@$MANAGER_IP "
  sed -i 's|backend-app:.*|backend-app:${NEW_VERSION}|' /home/ec2-user/docker-stack-${TARGET}.yml
  sed -i 's|frontend-app:.*|frontend-app:${NEW_VERSION}|' /home/ec2-user/docker-stack-${TARGET}.yml
  sed -i 's|80:80|${TEST_FRONTEND_PORT}:80|' /home/ec2-user/docker-stack-${TARGET}.yml
"

# Deploy target stack
ssh ec2-user@$MANAGER_IP "docker stack deploy -c /home/ec2-user/docker-stack-${TARGET}.yml empapp_${TARGET}"

# Health check
echo "⏳ Waiting for services..."
sleep 30
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$MANAGER_IP:$TEST_FRONTEND_PORT)

if [ "$HTTP_CODE" != "200" ]; then
  echo "❌ Health check failed. Rolling back."
  ssh ec2-user@$MANAGER_IP "docker stack rm empapp_${TARGET}"
  exit 1
fi

# Remove old stack
echo "🗑 Removing old stack $CURRENT..."
ssh ec2-user@$MANAGER_IP "docker stack rm empapp_${CURRENT} || true"
sleep 15

# Switch frontend to port 80
echo "🔄 Switching frontend to port 80..."
ssh ec2-user@$MANAGER_IP "sed -i 's|${TEST_FRONTEND_PORT}:80|80:80|' /home/ec2-user/docker-stack-${TARGET}.yml"
ssh ec2-user@$MANAGER_IP "docker stack deploy -c /home/ec2-user/docker-stack-${TARGET}.yml empapp_${TARGET}"

echo "🎉 Deployment completed. $TARGET stack is now live."
