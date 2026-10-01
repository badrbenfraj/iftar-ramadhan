#!/usr/bin/env bash
set -euo pipefail

DEFAULT_TARGET_HOST="ubuntu@92.222.128.157"
DEFAULT_ENV_FILE=".env"
DEFAULT_REMOTE_DIR="/home/ubuntu/iftar"

TARGET_HOST="${1:-$DEFAULT_TARGET_HOST}"
ENV_FILE="${2:-$DEFAULT_ENV_FILE}"
REMOTE_DIR="${3:-$DEFAULT_REMOTE_DIR}"
SSH_KEY="${4:-}"

echo "Using target host: $TARGET_HOST"
echo "Using env file: $ENV_FILE"
echo "Using remote dir: $REMOTE_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE"
  echo "Attempting to create it from available defaults..."

  if [[ -f "apps/backend/.env" ]]; then
    cp "apps/backend/.env" "$ENV_FILE"
    echo "Created $ENV_FILE from apps/backend/.env"
  elif [[ -f "apps/backend/.env.production" ]]; then
    cp "apps/backend/.env.production" "$ENV_FILE"
    echo "Created $ENV_FILE from apps/backend/.env.production"
  elif [[ -f "apps/backend/.env.development" ]]; then
    cp "apps/backend/.env.development" "$ENV_FILE"
    echo "Created $ENV_FILE from apps/backend/.env.development"
  elif [[ -f "apps/backend/.env.template" ]]; then
    cp "apps/backend/.env.template" "$ENV_FILE"
    echo "Created $ENV_FILE from apps/backend/.env.template"
  else
    cat > "$ENV_FILE" <<'EOL'
DOMAIN=vps-ca2a6790.vps.ovh.net
APP_ENV=development
APP_PORT=3000
DB_HOST=0.0.0.0
DB_PORT=5432
DB_NAME=iftar_db
DB_USER=iftar
DB_PASS=iftar@2026
ACME_EMAIL=change-me@example.com
JWT_ACCESS_TOKEN_EXP_IN_SEC=3000000
JWT_REFRESH_TOKEN_EXP_IN_SEC=3000000
JWT_PUBLIC_KEY_BASE64=
JWT_PRIVATE_KEY_BASE64=
DEFAULT_ADMIN_USER_PASSWORD=change-me
EOL
    echo "Created $ENV_FILE from built-in defaults"
  fi
fi

if [[ ! -f "docker-compose.yml" ]]; then
  echo "Error: docker-compose.yml not found in current directory"
  exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=accept-new"
if [[ -n "$SSH_KEY" ]]; then
  SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

echo "Deploying to $TARGET_HOST:$REMOTE_DIR"

# Ensure Docker + Compose are available on remote VPS
echo "Checking Docker prerequisites on remote VPS..."
ssh $SSH_OPTS "$TARGET_HOST" "bash -s" <<'REMOTE_SETUP'
set -euo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

echo "Installing/upgrading Docker to latest stable..."
if ! command -v curl >/dev/null 2>&1; then
  $SUDO apt-get update -y
  $SUDO apt-get install -y curl
fi
curl -fsSL https://get.docker.com | $SUDO sh

echo "Installing/upgrading Docker Compose to latest release..."
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) COMPOSE_ARCH="x86_64" ;;
  aarch64|arm64) COMPOSE_ARCH="aarch64" ;;
  *)
    echo "Unsupported architecture for Docker Compose: $ARCH"
    exit 1
    ;;
esac

COMPOSE_VERSION="$(curl -fsSL https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | head -n1 | sed -E 's/.*"([^"]+)".*/\1/')"
$SUDO mkdir -p /usr/local/lib/docker/cli-plugins
$SUDO curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" -o /usr/local/lib/docker/cli-plugins/docker-compose
$SUDO chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon not running. Starting docker service..."
  $SUDO systemctl enable --now docker
fi

echo "Docker version: $(docker --version)"
echo "Compose version: $(docker compose version)"

echo "Remote Docker is ready."
REMOTE_SETUP

# Ensure remote folder exists
ssh $SSH_OPTS "$TARGET_HOST" "mkdir -p '$REMOTE_DIR'"

# Upload required files
scp $SSH_OPTS docker-compose.yml "$TARGET_HOST:$REMOTE_DIR/docker-compose.yml"
scp $SSH_OPTS "$ENV_FILE" "$TARGET_HOST:$REMOTE_DIR/.env"

# Upload Caddyfile only if present (current stack uses it)
if [[ -f "Caddyfile" ]]; then
  scp $SSH_OPTS Caddyfile "$TARGET_HOST:$REMOTE_DIR/Caddyfile"
fi

# Apply deployment
ssh $SSH_OPTS "$TARGET_HOST" "cd '$REMOTE_DIR' && docker compose --env-file .env pull && docker compose --env-file .env up -d --remove-orphans && docker compose ps"

echo "Deployment completed."
