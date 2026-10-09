#!/bin/bash

echo "Setting up development environment..."

# Install system dependencies
echo "Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
fi

# Ensure docker group exists
if ! getent group docker > /dev/null; then
    sudo groupadd docker
fi

# Add current user to docker group
sudo usermod -aG docker $USER
sudo systemctl restart docker

# Verify docker permissions
echo "Setting up Docker permissions..."
sudo chown root:docker /var/run/docker.sock
sudo chmod 666 /var/run/docker.sock

# Install Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Create .env file
echo "Creating .env file with fresh random secrets..."
if [ -f .env ]; then
  echo ".env already exists, leaving it untouched."
else
  cp .env.example .env
  DB_PASS_VALUE=$(openssl rand -base64 24 | tr -d '/+=')
  ADMIN_PASS_VALUE=$(openssl rand -base64 24 | tr -d '/+=')
  openssl genrsa -out /tmp/iftar-jwt.pem 2048 2>/dev/null
  openssl rsa -in /tmp/iftar-jwt.pem -pubout -out /tmp/iftar-jwt.pub 2>/dev/null
  JWT_PRIVATE=$(base64 -w0 /tmp/iftar-jwt.pem)
  JWT_PUBLIC=$(base64 -w0 /tmp/iftar-jwt.pub)
  rm -f /tmp/iftar-jwt.pem /tmp/iftar-jwt.pub
  sed -i \
    -e "s|^DB_PASS=.*|DB_PASS=${DB_PASS_VALUE}|" \
    -e "s|^DEFAULT_ADMIN_USER_PASSWORD=.*|DEFAULT_ADMIN_USER_PASSWORD=${ADMIN_PASS_VALUE}|" \
    -e "s|^JWT_PRIVATE_KEY_BASE64=.*|JWT_PRIVATE_KEY_BASE64=${JWT_PRIVATE}|" \
    -e "s|^JWT_PUBLIC_KEY_BASE64=.*|JWT_PUBLIC_KEY_BASE64=${JWT_PUBLIC}|" \
    .env
  chmod 600 .env
  echo "Admin password (shown once, store it safely): ${ADMIN_PASS_VALUE}"
fi
echo "Set DOMAIN and ACME_EMAIL in .env before starting the stack."
echo "IMPORTANT: You need to log out and log back in for the Docker group changes to take effect."
echo "After logging back in, you can run: docker-compose up -d"

# Make the script executable
chmod +x setup.sh

# Provide immediate solution for current session
echo "To use Docker in current session without logging out, run:"
echo "newgrp docker"
