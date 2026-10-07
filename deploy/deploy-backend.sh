#!/usr/bin/env bash
# Deploys (or updates) the backend stack: Caddy (HTTPS) + API + Postgres.
# Safe to re-run; also used for the very first deployment on a new server.
#
#   SERVER_HOST=vps-xxxx.vps.ovh.net SSH_USER=ubuntu deploy/deploy-backend.sh <env file>
#
# The env file becomes /opt/iftar/.env (see .env.example at the repo root).
# shellcheck source=deploy/common.sh
source "$(dirname "$0")/common.sh"
ENV_FILE="${1:?Usage: deploy-backend.sh <env file>}"
[ -f "$ENV_FILE" ] || { echo "Env file not found: $ENV_FILE" >&2; exit 1; }
cd "$REPO_ROOT"

log "Preparing $TARGET:$APP_DIR"
remote_script deploy/server/bootstrap.sh "$APP_DIR"

log "Uploading the stack and the backend source"
tar -czf - \
  --exclude=node_modules --exclude=dist --exclude=coverage --exclude='.env*' \
  --exclude=releases --exclude=test-report.xml \
  docker-compose.yml Caddyfile apps/backend \
  | remote "set -e; cd '$APP_DIR'; rm -rf apps/backend; tar -xzf -"
remote "umask 077; cat > '$APP_DIR/.env.tmp' && mv -f '$APP_DIR/.env.tmp' '$APP_DIR/.env'" < "$ENV_FILE"

log "Building and starting the containers"
remote "set -e; cd '$APP_DIR'
  docker compose up -d --build --remove-orphans
  docker image prune -f >/dev/null
  for i in \$(seq 60); do
    status=\$(docker inspect -f '{{.State.Health.Status}}' iftar-app 2>/dev/null || true)
    [ \"\$status\" = healthy ] && break
    sleep 3
  done
  docker compose ps
  [ \"\$status\" = healthy ] || { docker compose logs --tail=80 app; echo 'API did not become healthy' >&2; exit 1; }"

log "Checking https://$SERVER_HOST (the first run waits for the certificate)"
curl -fsS --retry 20 --retry-delay 6 --retry-all-errors \
  "https://$SERVER_HOST/api/v1/health" >/dev/null
curl -fsS "https://$SERVER_HOST/api/v1/app/version"; echo
log "Backend is up: https://$SERVER_HOST/download"
