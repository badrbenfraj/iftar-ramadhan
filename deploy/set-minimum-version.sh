#!/usr/bin/env bash
# Forces installed apps older than <version> to update before they can be used.
#
#   SERVER_HOST=... SSH_USER=ubuntu deploy/set-minimum-version.sh 1.4.0
#
# Takes effect on each app's next start (or resume after an hour). Use 0.0.0
# to remove the requirement. A value above the latest release is capped to it.
# shellcheck source=deploy/common.sh
source "$(dirname "$0")/common.sh"
VERSION="${1:?Usage: set-minimum-version.sh <version>}"
is_semver "$VERSION" || { echo "Version must look like 1.4.0, got '$VERSION'" >&2; exit 1; }

remote "set -e; mkdir -p '$RELEASES_DIR'; cd '$RELEASES_DIR'
  echo '$VERSION' > minimum-version.tmp && mv -f minimum-version.tmp minimum-version"
log "minimum-version is now $VERSION"
curl -fsS "https://$SERVER_HOST/api/v1/app/version"; echo
