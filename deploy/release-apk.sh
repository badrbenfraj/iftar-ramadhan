#!/usr/bin/env bash
# Publishes a built APK as the new latest release.
#
#   SERVER_HOST=... SSH_USER=ubuntu deploy/release-apk.sh <app-release.apk> <version>
#
# Upload to app-<version>.apk.tmp -> verify SHA-256 on the server -> rename to
# app-<version>.apk -> atomically switch latest.apk -> rewrite latest.json ->
# download it back over HTTPS and check the checksum.
# shellcheck source=deploy/common.sh
source "$(dirname "$0")/common.sh"
APK="${1:?Usage: release-apk.sh <apk> <version>}"
VERSION="${2:?Usage: release-apk.sh <apk> <version>}"
is_semver "$VERSION" || { echo "Version must look like 1.5.0, got '$VERSION'" >&2; exit 1; }
[ -f "$APK" ] || { echo "APK not found: $APK" >&2; exit 1; }
cd "$REPO_ROOT"

SHA="$(sha256_of "$APK")"
log "Releasing $VERSION (sha256 $SHA)"

remote "mkdir -p '$RELEASES_DIR'"
scp "${SSH_OPTS[@]}" "$APK" "$TARGET:$RELEASES_DIR/app-$VERSION.apk.tmp"
remote_script deploy/server/publish-apk.sh "$RELEASES_DIR" "$VERSION" "$SHA"

log "Verifying what volunteers will download"
TMP_DL="$(mktemp)"
trap 'rm -f "$TMP_DL"' EXIT
curl -fsSL --retry 3 "https://$SERVER_HOST/releases/latest.apk" -o "$TMP_DL"
[ "$(sha256_of "$TMP_DL")" = "$SHA" ] || { echo "Downloaded latest.apk does not match the release checksum" >&2; exit 1; }
curl -fsS "https://$SERVER_HOST/api/v1/app/version" | grep -q "\"latestVersion\":\"$VERSION\"" \
  || { echo "/api/v1/app/version does not report $VERSION" >&2; exit 1; }
log "Released $VERSION: https://$SERVER_HOST/download"
