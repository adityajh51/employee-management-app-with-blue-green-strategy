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
else
  CURRENT="blue"
fi

# Test frontend port for new stack
TEST_FRONTEND_PORT=8082

echo "➡️ Deploying $TARGET stack on test port $TEST_FRONTEND_PORT..."

# Copy stack file
scp -o StrictHostKeyChecking=no docker-stack-${TARGET}.yml ec2-user@$MANAGER_IP:/home/ec2-user/

# Update image versions and test frontend port
ssh ec2-user@$MANAGER_IP "
  sed -i 's|backend-app:.*|backend-app:${NEW_VERSION}|' /home/ec2-user/docker-stack-${TARGET}.yml
  sed -i 's|frontend-app:.*|frontend-app:${NEW_VERSION}|' /home/ec2-user/docker-stack-${TARGET}.yml
  sed -i 's|80:80|${TEST_FRONTEND_PORT}:80|' /home/ec2-user/docker-stack-${TARGET}.yml
"

# Deploy for testing
ssh ec2-user@$MANAGER_IP "docker stack deploy -c /home/ec2-user/docker-stack-${TARGET}.yml empapp_${TARGET}"

# Health check with retries
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
ssh ec2-user@$MANAGER_IP "sed -i 's|${TEST_FRONTEND_PORT}:80|80:80|' /home/ec2-user/docker-stack-${TARGET}.yml"

# Redeploy Green stack on port 80
echo "🚀 Redeploying $TARGET stack on port 80..."
ssh ec2-user@$MANAGER_IP "docker stack deploy -c /home/ec2-user/docker-stack-${TARGET}.yml empapp_${TARGET}"

echo "🎉 Deployment completed. $TARGET stack is now live on port 80."
