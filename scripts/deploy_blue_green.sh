#!/bin/bash
set -e

# ------------------------------
# Usage: ./deploy.sh <MANAGER_IP> <NEW_VERSION> <TARGET>
# TARGET: blue or green
# ------------------------------

MANAGER_IP=$1
NEW_VERSION=$2
TARGET=$3   # blue or green

if [ -z "$TARGET" ] || [ -z "$MANAGER_IP" ] || [ -z "$NEW_VERSION" ]; then
  echo "❌ Usage: $0 <MANAGER_IP> <NEW_VERSION> <TARGET (blue|green)>"
  exit 1
fi

# Determine opposite color
if [ "$TARGET" == "blue" ]; then
  CURRENT="green"
  TEST_FRONTEND_PORT=8080
  TEST_BACKEND_PORT=8080
else
  CURRENT="blue"
  TEST_FRONTEND_PORT=8082
  TEST_BACKEND_PORT=8081
fi

STACK_FILE="docker-stack-${TARGET}.yml"
REMOTE_PATH="/home/ec2-user/${STACK_FILE}"

echo "➡️ Deploying $TARGET stack on test port $TEST_FRONTEND_PORT..."

# Copy stack file to manager
scp -o StrictHostKeyChecking=no "$STACK_FILE" ec2-user@$MANAGER_IP:$REMOTE_PATH

# Update images and frontend port for testing
ssh ec2-user@$MANAGER_IP "
  sed -i 's|backend-app:.*|backend-app:${NEW_VERSION}|' $REMOTE_PATH
  sed -i 's|frontend-app:.*|frontend-app:${NEW_VERSION}|' $REMOTE_PATH
  sed -i 's|808[0-9]:80|${TEST_FRONTEND_PORT}:80|' $REMOTE_PATH
  sed -i 's|808[0-9]:8080|${TEST_BACKEND_PORT}:8080|' $REMOTE_PATH
"

# Deploy target stack for testing
ssh ec2-user@$MANAGER_IP "docker stack deploy -c $REMOTE_PATH empapp_${TARGET}"

# Health check
MAX_RETRIES=12
SLEEP_TIME=10
HEALTH_URL="http://${MANAGER_IP}:${TEST_FRONTEND_PORT}/"

echo "⏳ Waiting for services to stabilize..."
for i in $(seq 1 $MAX_RETRIES); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL || echo 0)
  if [ "$HTTP_CODE" == "200" ]; then
    echo "✅ $TARGET stack is healthy!"
    break
  else
    echo "Waiting for service... attempt $i/$MAX_RETRIES"
    sleep $SLEEP_TIME
  fi
done

if [ "$HTTP_CODE" != "200" ]; then
  echo "❌ Health check failed. Rolling back..."
  ssh ec2-user@$MANAGER_IP "docker stack rm empapp_${TARGET}"
  exit 1
fi

# Remove old stack
echo "🗑 Removing old $CURRENT stack..."
ssh ec2-user@$MANAGER_IP "docker stack rm empapp_${CURRENT} || true"
sleep 15

# Switch frontend to port 80
echo "🔄 Switching $TARGET frontend to port 80..."
ssh ec2-user@$MANAGER_IP "sed -i 's|${TEST_FRONTEND_PORT}:80|80:80|' $REMOTE_PATH"

# Redeploy target stack on port 80
echo "🚀 Redeploying $TARGET stack on port 80..."
ssh ec2-user@$MANAGER_IP "docker stack deploy -c $REMOTE_PATH empapp_${TARGET}"

echo "🎉 Deployment completed. $TARGET stack is now live on port 80."
