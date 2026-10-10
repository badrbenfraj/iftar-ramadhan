#!/usr/bin/env bash
# Publishes a built web app (flutter build web) as https://<server>/app/.
#
#   SERVER_HOST=... SSH_USER=ubuntu deploy/release-web.sh <build/web dir> <version>
#
# Upload to web/<version>-<time>.tmp -> rename -> atomically switch
# web/current -> check that /app/version.json reports <version>.
# shellcheck source=deploy/common.sh
source "$(dirname "$0")/common.sh"
BUILD="${1:?Usage: release-web.sh <build dir> <version>}"
VERSION="${2:?Usage: release-web.sh <build dir> <version>}"
is_semver "$VERSION" || { echo "Version must look like 1.5.0, got '$VERSION'" >&2; exit 1; }
[ -f "$BUILD/index.html" ] || { echo "No index.html in $BUILD" >&2; exit 1; }
cd "$REPO_ROOT"

RELEASE="$VERSION-$(date -u +%Y%m%d%H%M%S)"
log "Releasing web $RELEASE"
remote "mkdir -p '$APP_DIR/web/$RELEASE.tmp'"
tar -czf - -C "$BUILD" . | remote "tar -xzf - -C '$APP_DIR/web/$RELEASE.tmp'"
remote_script deploy/server/publish-web.sh "$APP_DIR/web" "$RELEASE"

log "Verifying what iPhones will load"
curl -fsS --retry 3 "https://$SERVER_HOST/app/version.json" | grep -q "\"version\":\"$VERSION\"" \
  || { echo "/app/version.json does not report $VERSION" >&2; exit 1; }
log "Released web $VERSION: https://$SERVER_HOST/app/"
