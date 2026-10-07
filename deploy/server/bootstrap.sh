#!/usr/bin/env bash
# Runs ON THE SERVER (piped over SSH by deploy-backend.sh). Idempotent: on a
# fresh OVH server it installs Docker and creates the install directory; on
# later runs it changes nothing.
#
#   bootstrap.sh <app dir>
set -euo pipefail
APP_DIR="$1"
SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo -n"; fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker (first deployment on this server)..."
  curl -fsSL https://get.docker.com | $SUDO sh
  # Lets the SSH user run docker without sudo from the next SSH session on.
  $SUDO usermod -aG docker "$(id -un)"
fi
$SUDO systemctl enable --now docker >/dev/null 2>&1 || true

if [ ! -d "$APP_DIR" ]; then
  $SUDO mkdir -p "$APP_DIR"
  $SUDO chown "$(id -u):$(id -g)" "$APP_DIR"
fi
mkdir -p "$APP_DIR/releases"
# No forced update until someone raises it (docs/DEPLOYMENT.md).
[ -f "$APP_DIR/releases/minimum-version" ] || echo "0.0.0" > "$APP_DIR/releases/minimum-version"

docker --version
docker compose version
