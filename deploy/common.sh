# shellcheck shell=bash disable=SC2034,SC2029  # vars used by sourcing scripts; ssh args expand locally on purpose
# Shared by the deploy scripts. Configuration comes from the environment:
#
#   SERVER_HOST  server hostname, e.g. vps-xxxx.vps.ovh.net   (required)
#   SSH_USER     SSH login on the server, e.g. ubuntu          (required)
#   SSH_KEY      private key file (optional; default: your ssh-agent/config)
#   APP_DIR      install directory on the server (default /opt/iftar)
set -euo pipefail

: "${SERVER_HOST:?Set SERVER_HOST to the server hostname (e.g. vps-xxxx.vps.ovh.net)}"
: "${SSH_USER:?Set SSH_USER to the SSH login on the server (e.g. ubuntu)}"
APP_DIR="${APP_DIR:-/opt/iftar}"
RELEASES_DIR="$APP_DIR/releases"
TARGET="$SSH_USER@$SERVER_HOST"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A new server each Ramadan means an unknown host key: accept it the first
# time, refuse it if it later changes.
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ServerAliveInterval=30)
if [ -n "${SSH_KEY:-}" ]; then SSH_OPTS+=(-i "$SSH_KEY"); fi

remote() { ssh "${SSH_OPTS[@]}" "$TARGET" "$@"; }

# Runs a local script on the server with arguments: remote_script file args...
remote_script() {
  local script="$1"; shift
  ssh "${SSH_OPTS[@]}" "$TARGET" "bash -s -- $(printf '%q ' "$@")" < "$script"
}

is_semver() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }

sha256_of() {
  if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

log() { printf '\n==> %s\n' "$*"; }
