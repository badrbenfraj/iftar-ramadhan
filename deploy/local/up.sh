#!/usr/bin/env bash
# Starts the local stack (deploy/local/compose.yml). Needs only Docker and
# bash (Git Bash on Windows, Terminal on macOS/Linux). Guide:
# docs/LOCAL_DEVELOPMENT.md.
#
#   deploy/local/up.sh               start; build the web app if needed
#   deploy/local/up.sh --build-web   rebuild the web app (after Flutter changes)
#   deploy/local/up.sh down          stop (data is kept in Docker volumes)
#
# LAN_IP defaults to this PC's Wi-Fi/Ethernet address; override with LAN_IP=...
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
compose=(docker compose -f "$here/compose.yml")

if [ "${1:-}" = down ]; then
  LAN_IP=x "${compose[@]}" down
  exit
fi

# This machine's address on the local network (Windows, macOS, Linux).
detect_lan_ip() {
  if command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command \
      "(Get-NetIPConfiguration | Where-Object IPv4DefaultGateway | Select-Object -First 1).IPv4Address.IPAddress" |
      tr -d '\r'
  elif [ "$(uname)" = Darwin ]; then
    ipconfig getifaddr "$(route -n get default | awk '/interface:/ {print $2}')"
  else
    ip route get 1.1.1.1 | awk '{for (i = 1; i < NF; i++) if ($i == "src") print $(i + 1)}'
  fi
}
export LAN_IP="${LAN_IP:-$(detect_lan_ip)}"
[ -n "$LAN_IP" ] || { echo "Could not find the LAN IP; run: LAN_IP=192.168.x.y $0" >&2; exit 1; }
echo "LAN IP: $LAN_IP"

# .env: dev-only JWT keys and admin password, generated once (git-ignored).
if [ ! -f "$here/.env" ]; then
  echo "Generating deploy/local/.env..."
  docker run --rm alpine:3 sh -c '
    apk add -q --no-cache openssl >/dev/null
    openssl genrsa -out k 2048 2>/dev/null && openssl rsa -in k -pubout -out k.pub 2>/dev/null
    echo "JWT_PUBLIC_KEY_BASE64=$(base64 -w0 k.pub)"
    echo "JWT_PRIVATE_KEY_BASE64=$(base64 -w0 k)"
    echo "JWT_ACCESS_TOKEN_EXP_IN_SEC=3600"
    echo "JWT_REFRESH_TOKEN_EXP_IN_SEC=7200"
    echo "DEFAULT_ADMIN_USER_PASSWORD=admin-test-pass"
  ' > "$here/.env"
fi

# The web app has the API address compiled in, so rebuild when the IP changes.
web="$root/apps/mobile/build/web"
if [ "${1:-}" = --build-web ] || [ "$(cat "$web/.lan_ip" 2>/dev/null)" != "$LAN_IP" ]; then
  echo "Building the web app for https://$LAN_IP:8443 (~2 min)..."
  cd "$root/apps/mobile"
  # pwd -W gives a Windows path in Git Bash; plain pwd elsewhere.
  MSYS_NO_PATHCONV=1 docker run --rm \
    -v "$(pwd -W 2>/dev/null || pwd):/app" -v iftar_pub_cache:/root/.pub-cache -w /app \
    "$(tool/flutter-image.sh)" \
    flutter build web --release --base-href /app/ \
      --dart-define=APP_ENV=local --dart-define=API_URL="https://$LAN_IP:8443"
  echo "$LAN_IP" > "$web/.lan_ip"
fi

"${compose[@]}" up -d
echo
echo "Web app:  https://$LAN_IP:8443/app/  (accept the certificate warning once)"
echo "API:      http://localhost:3300/api/v1/health  (first start runs npm ci, ~1 min)"
echo "Adminer:  http://localhost:8081  (server db, user/password iftar)"
echo "Login:    admin / admin-test-pass, or a seeded account (password test-pass)"
