#!/usr/bin/env bash
# Points latest.apk (and /download) back at an APK already on the server.
#
#   SERVER_HOST=... SSH_USER=ubuntu deploy/rollback-apk.sh 1.4.0
#
# Only NEW downloads get the older APK: Android refuses to install a lower
# version over a higher one, so phones that already updated keep their
# version. To fix those, release the old code under a new, higher version.
# shellcheck source=deploy/common.sh
source "$(dirname "$0")/common.sh"
VERSION="${1:?Usage: rollback-apk.sh <version>}"
is_semver "$VERSION" || { echo "Version must look like 1.4.0, got '$VERSION'" >&2; exit 1; }
cd "$REPO_ROOT"
remote_script deploy/server/publish-apk.sh "$RELEASES_DIR" "$VERSION"
