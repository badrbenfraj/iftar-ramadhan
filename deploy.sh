#!/bin/bash

ENV=$1
TARGET_HOST=$2
SSH_KEY=$3

if [ -z "$ENV" ] || [ -z "$TARGET_HOST" ] || [ -z "$SSH_KEY" ]; then
    echo "Usage: ./deploy.sh [environment] [target_host] [ssh_key_path]"
    echo "Example: ./deploy.sh prod user@hostname ~/.ssh/id_rsa"
    exit 1
fi

echo "🚀 Deploying to $ENV environment on $TARGET_HOST"

# Load appropriate environment file
ENV_FILE=".env.$ENV"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Environment file $ENV_FILE not found!"
    exit 1
fi

# Create deployment directory structure
DEPLOY_DIR="deploy"
mkdir -p $DEPLOY_DIR

# Copy necessary files
echo "📦 Preparing deployment package..."
cp docker-compose.yml $DEPLOY_DIR/
cp $ENV_FILE $DEPLOY_DIR/.env

# Create deploy script
cat > $DEPLOY_DIR/run.sh << 'EOL'
#!/bin/bash
set -e

# Pull latest images
docker compose pull

# Stop and remove existing containers
docker compose down

# Start new containers
docker compose up -d

# Wait for health checks
echo "⏳ Waiting for services to be healthy..."
sleep 30

# Verify deployment
if docker compose ps | grep -q "Up"; then
    echo "✅ Deployment successful!"
else
    echo "❌ Deployment failed!"
    docker compose logs
    exit 1
fi
EOL

chmod +x $DEPLOY_DIR/run.sh

# Create cleanup script
cat > $DEPLOY_DIR/cleanup.sh << 'EOL'
#!/bin/bash

# Remove unused images and volumes
docker system prune -af
docker volume prune -f

# Keep only last 5 backups
cd /data/backups && ls -t | tail -n +6 | xargs -r rm --
EOL

chmod +x $DEPLOY_DIR/cleanup.sh

# Deploy to remote server
echo "📤 Deploying to remote server..."
rsync -avz --delete -e "ssh -i $SSH_KEY" \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude 'dist' \
    $DEPLOY_DIR/ $TARGET_HOST:/opt/iftar-ramadhan/

# Execute deployment
ssh -i $SSH_KEY $TARGET_HOST "cd /opt/iftar-ramadhan && ./run.sh"

# Cleanup local deployment directory
rm -rf $DEPLOY_DIR

echo "🎉 Deployment completed!"
