#!/bin/bash
set -e

# -----------------------------------------
# Usage: ./deploy.sh <MANAGER_IP> <NEW_VERSION> <TARGET>
# Example: ./deploy.sh 54.201.xx.xx v2 green
# TARGET: blue or green
# -----------------------------------------

MANAGER_IP=$1
NEW_VERSION=$2
TARGET=$3      # blue or green

if [ -z "$MANAGER_IP" ] || [ -z "$NEW_VERSION" ] || [ -z "$TARGET" ]; then
  echo "Usage: $0 <MANAGER_IP> <NEW_VERSION> <TARGET (blue|green)>"
  exit 1
fi

STACK_DB="docker-stack-db.yml"
STACK_APP="docker-stack-app.yml"
REMOTE_DB_PATH="/home/ec2-user/${STACK_DB}"
REMOTE_APP_PATH="/home/ec2-user/${STACK_APP}"

NETWORK_NAME="emp_network"
DB_STACK_NAME="empapp_db"

# ------------------------------
# Step 0: Ensure overlay network exists
# ------------------------------
echo "Checking if overlay network '$NETWORK_NAME' exists..."
NETWORK_EXISTS=$(ssh ec2-user@$MANAGER_IP "docker network ls --format '{{.Name}}' | grep -w $NETWORK_NAME || true")

if [ -z "$NETWORK_EXISTS" ]; then
  echo "Creating overlay network '$NETWORK_NAME'..."
  ssh ec2-user@$MANAGER_IP "docker network create --driver overlay --attachable $NETWORK_NAME"
else
  echo "Network '$NETWORK_NAME' already exists."
fi

# ------------------------------
# Step 1: Deploy MySQL database stack if not running
# ------------------------------
echo "Checking if MySQL stack is running..."
DB_EXISTS=$(ssh ec2-user@$MANAGER_IP "docker stack ls --format '{{.Name}}' | grep -w $DB_STACK_NAME || true")

if [ -z "$DB_EXISTS" ]; then
  echo "Deploying MySQL database stack..."
  scp -o StrictHostKeyChecking=no "$STACK_DB" ec2-user@$MANAGER_IP:$REMOTE_DB_PATH
  ssh ec2-user@$MANAGER_IP "docker stack deploy -c $REMOTE_DB_PATH $DB_STACK_NAME"
else
  echo "MySQL database stack is already running."
fi

# ------------------------------
# Step 2: Wait for MySQL service to become healthy
# ------------------------------
echo "Waiting for MySQL service to be ready..."
MAX_RETRIES=12
SLEEP_TIME=10

for i in $(seq 1 $MAX_RETRIES); do
  HEALTH_STATUS=$(ssh ec2-user@$MANAGER_IP \
    "docker inspect --format='{{json .State.Health.Status}}' \$(docker ps -q -f name=${DB_STACK_NAME}_mysqldb) 2>/dev/null" || echo "null")

  if [[ "$HEALTH_STATUS" == *"healthy"* ]]; then
    echo "MySQL service is healthy."
    break
  else
    echo "Waiting for MySQL... attempt $i/$MAX_RETRIES"
    sleep $SLEEP_TIME
  fi
done

if [[ "$HEALTH_STATUS" != *"healthy"* ]]; then
  echo "MySQL service failed to become healthy. Exiting."
  exit 1
fi

# ------------------------------
# Step 3: Configure blue/green target and ports
# ------------------------------
if [ "$TARGET" == "blue" ]; then
  CURRENT="green"
  LIVE_FRONTEND_PORT=80
  LIVE_BACKEND_PORT=8080
  TEST_FRONTEND_PORT=8082
  TEST_BACKEND_PORT=8081
else
  CURRENT="blue"
  LIVE_FRONTEND_PORT=80
  LIVE_BACKEND_PORT=8080
  TEST_FRONTEND_PORT=8082
  TEST_BACKEND_PORT=8081
fi

# ------------------------------
# Step 4: Deploy target stack on test ports
# ------------------------------
echo "Deploying $TARGET stack on test ports..."
scp -o StrictHostKeyChecking=no "$STACK_APP" ec2-user@$MANAGER_IP:$REMOTE_APP_PATH

ssh ec2-user@$MANAGER_IP "
  VERSION=${NEW_VERSION} FRONTEND_PORT=${TEST_FRONTEND_PORT} BACKEND_PORT=${TEST_BACKEND_PORT} \
  envsubst < $REMOTE_APP_PATH | docker stack deploy -c - empapp_${TARGET}
"

# ------------------------------
# Step 5: Health check on test URL
# ------------------------------
HEALTH_URL="http://${MANAGER_IP}:${TEST_FRONTEND_PORT}/"
echo "Waiting for frontend on $HEALTH_URL ..."

for i in $(seq 1 $MAX_RETRIES); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL || echo 0)
  if [ "$HTTP_CODE" == "200" ]; then
    echo "$TARGET stack passed health check!"
    break
  else
    echo "Waiting for service... attempt $i/$MAX_RETRIES"
    sleep $SLEEP_TIME
  fi
done

if [ "$HTTP_CODE" != "200" ]; then
  echo "Health check failed. Rolling back..."
  ssh ec2-user@$MANAGER_IP "docker stack rm empapp_${TARGET}"
  exit 1
fi

# ------------------------------
# Step 6: Remove old stack
# ------------------------------
echo "Removing old $CURRENT stack..."
ssh ec2-user@$MANAGER_IP "docker stack rm empapp_${CURRENT} || true"
sleep 15

# ------------------------------
# Step 7: Promote target stack to live ports
# ------------------------------
echo "Promoting $TARGET stack to live ports (80/8080)..."

ssh ec2-user@$MANAGER_IP "
  VERSION=${NEW_VERSION} FRONTEND_PORT=${LIVE_FRONTEND_PORT} BACKEND_PORT=${LIVE_BACKEND_PORT} \
  envsubst < $REMOTE_APP_PATH | docker stack deploy -c - empapp_${TARGET}
"

echo "Deployment completed. $TARGET stack is now live on port 80."
