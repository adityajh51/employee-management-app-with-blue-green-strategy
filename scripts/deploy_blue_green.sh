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

STACK_DB="docker-stack-db.yml"
STACK_FILE="docker-stack-${TARGET}.yml"
REMOTE_PATH="/home/ec2-user/${STACK_FILE}"
REMOTE_DB_PATH="/home/ec2-user/${STACK_DB}"
NETWORK_NAME="emp_network"

# ------------------------------
# Step 0: Ensure overlay network exists
# ------------------------------
echo "🔍 Checking if overlay network '$NETWORK_NAME' exists..."
NETWORK_EXISTS=$(ssh ec2-user@$MANAGER_IP "docker network ls --format '{{.Name}}' | grep -w $NETWORK_NAME || true")
if [ -z "$NETWORK_EXISTS" ]; then
  echo "➡️ Network '$NETWORK_NAME' not found. Creating..."
  ssh ec2-user@$MANAGER_IP "docker network create --driver overlay --attachable $NETWORK_NAME"
else
  echo "✅ Network '$NETWORK_NAME' already exists."
fi

# ------------------------------
# Step 1: Ensure MySQL stack exists and is running
# ------------------------------
echo "🔍 Checking if MySQL stack is running..."
DB_EXISTS=$(ssh ec2-user@$MANAGER_IP "docker stack ls --format '{{.Name}}' | grep -w empapp_db || true")
if [ -z "$DB_EXISTS" ]; then
  echo "➡️ MySQL stack not found. Deploying..."
  scp -o StrictHostKeyChecking=no "$STACK_DB" ec2-user@$MANAGER_IP:$REMOTE_DB_PATH
  ssh ec2-user@$MANAGER_IP "docker stack deploy -c $REMOTE_DB_PATH empapp_db"
else
  echo "✅ MySQL stack already exists."
fi

# Wait until MySQL service is running
echo "⏳ Waiting for MySQL service to be ready..."
MAX_RETRIES=12
SLEEP_TIME=5
for i in $(seq 1 $MAX_RETRIES); do
  RUNNING=$(ssh ec2-user@$MANAGER_IP "docker service ps empapp_db_mysqldb --filter 'desired-state=running' --format '{{.Name}}'" || true)
  if [ -n "$RUNNING" ]; then
    echo "✅ MySQL service is running."
    break
  else
    echo "Waiting for MySQL... attempt $i/$MAX_RETRIES"
    sleep $SLEEP_TIME
  fi
done

# ------------------------------
# Step 2: Determine target stack ports
# ------------------------------
if [ "$TARGET" == "blue" ]; then
  CURRENT="green"
  TEST_FRONTEND_PORT=80
  TEST_BACKEND_PORT=8080
else
  CURRENT="blue"
  TEST_FRONTEND_PORT=8082
  TEST_BACKEND_PORT=8081
fi

# ------------------------------
# Step 3: Deploy target blue/green stack
# ------------------------------
echo "➡️ Deploying $TARGET stack on test port $TEST_FRONTEND_PORT..."
scp -o StrictHostKeyChecking=no "$STACK_FILE" ec2-user@$MANAGER_IP:$REMOTE_PATH

ssh ec2-user@$MANAGER_IP "
  sed -i 's|backend-app:.*|backend-app:${NEW_VERSION}|' $REMOTE_PATH
  sed -i 's|frontend-app:.*|frontend-app:${NEW_VERSION}|' $REMOTE_PATH
  sed -i 's|808[0-9]:80|${TEST_FRONTEND_PORT}:80|' $REMOTE_PATH
  sed -i 's|808[0-9]:8080|${TEST_BACKEND_PORT}:8080|' $REMOTE_PATH
"

ssh ec2-user@$MANAGER_IP "docker stack deploy -c $REMOTE_PATH empapp_${TARGET}"

# ------------------------------
# Step 4: Health check
# ------------------------------
HEALTH_URL="http://${MANAGER_IP}:${TEST_FRONTEND_PORT}/"
echo "⏳ Waiting for frontend to respond..."
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

# ------------------------------
# Step 5: Remove old stack
# ------------------------------
echo "🗑 Removing old $CURRENT stack..."
ssh ec2-user@$MANAGER_IP "docker stack rm empapp_${CURRENT} || true"
sleep 15

# ------------------------------
# Step 6: Switch frontend to port 80
# ------------------------------
echo "🔄 Switching $TARGET frontend to port 80..."
ssh ec2-user@$MANAGER_IP "sed -i 's|${TEST_FRONTEND_PORT}:80|80:80|' $REMOTE_PATH"

ssh ec2-user@$MANAGER_IP "docker stack deploy -c $REMOTE_PATH empapp_${TARGET}"

echo "🎉 Deployment completed. $TARGET stack is now live on port 80."
