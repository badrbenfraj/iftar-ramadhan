#!/usr/bin/env bash
# Runs ON THE SERVER (piped over SSH by release-web.sh).
#
#   publish-web.sh <web dir> <release>
#
# 1. Rename the uploaded <release>.tmp to <release> (atomic, same directory).
# 2. Point current at it with an atomic symlink swap: a page load gets the
#    old or the new build, never a mix.
# 3. Keep the 5 newest releases, for a quick rollback by hand:
#      ln -sfn <older release> current.new && mv -Tf current.new current
set -euo pipefail
DIR="$1"; RELEASE="$2"
cd "$DIR"
[ -f "$RELEASE.tmp/index.html" ] || { echo "$DIR/$RELEASE.tmp has no index.html." >&2; exit 1; }
chmod -R a+rX "$RELEASE.tmp"
mv "$RELEASE.tmp" "$RELEASE"

ln -sfn "$RELEASE" current.new
mv -Tf current.new current

# Uploads that never finished, then all but the 5 newest releases.
find . -maxdepth 1 -name '*.tmp' -type d -mmin +60 -exec rm -rf {} +
ls -1d [0-9]*/ 2>/dev/null | sed 's:/$::' | grep -v '\.tmp$' | sort -V | head -n -5 \
  | while read -r old; do [ "$old" = "$RELEASE" ] || rm -rf "$old"; done

echo "current -> $RELEASE"
ls -l "$DIR"
