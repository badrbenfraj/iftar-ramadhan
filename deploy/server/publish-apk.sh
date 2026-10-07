#!/usr/bin/env bash
# Runs ON THE SERVER (piped over SSH by release-apk.sh / rollback-apk.sh).
#
#   publish-apk.sh <releases dir> <version> [expected sha256]
#
# 1. If app-<version>.apk.tmp was just uploaded: check its SHA-256, then
#    rename it to app-<version>.apk (same directory, so the rename is atomic
#    and nobody can download a half-uploaded file).
# 2. Point latest.apk at app-<version>.apk with an atomic symlink swap.
# 3. Rewrite latest.json (atomic rename), which the API serves.
#
# Old APKs are never deleted. Called without a fresh upload, it re-points
# latest.apk to an existing version (rollback).
set -euo pipefail
DIR="$1"; VERSION="$2"; EXPECTED="${3:-}"
cd "$DIR"
FINAL="app-$VERSION.apk"
TMP="$FINAL.tmp"

if [ -f "$TMP" ]; then
  ACTUAL="$(sha256sum "$TMP" | cut -d' ' -f1)"
  if [ -z "$EXPECTED" ] || [ "$ACTUAL" != "$EXPECTED" ]; then
    rm -f "$TMP"
    echo "Checksum mismatch for the uploaded APK (expected '$EXPECTED', got '$ACTUAL')." >&2
    exit 1
  fi
  if [ -e "$FINAL" ]; then
    if [ "$(sha256sum "$FINAL" | cut -d' ' -f1)" != "$ACTUAL" ]; then
      rm -f "$TMP"
      echo "$FINAL already exists with different content. Releases are immutable: bump the version in apps/mobile/pubspec.yaml." >&2
      exit 1
    fi
    rm -f "$TMP" # Same file re-uploaded (workflow re-run): nothing to replace.
  else
    chmod 644 "$TMP"
    mv "$TMP" "$FINAL"
  fi
fi

[ -f "$FINAL" ] || { echo "$DIR/$FINAL does not exist." >&2; exit 1; }
SHA="$(sha256sum "$FINAL" | cut -d' ' -f1)"
echo "$SHA  $FINAL" > "$FINAL.sha256"

# rename(2) over the old symlink is atomic: a download gets the old or the
# new APK, never a mix.
ln -sfn "$FINAL" latest.apk.new
mv -Tf latest.apk.new latest.apk

cat > latest.json.tmp <<JSON
{
  "version": "$VERSION",
  "sha256": "$SHA",
  "file": "$FINAL",
  "releasedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON
mv -f latest.json.tmp latest.json
[ -f minimum-version ] || echo "0.0.0" > minimum-version

echo "latest.apk -> $FINAL ($SHA)"
echo "minimum-version: $(cat minimum-version)"
ls -l "$DIR"
