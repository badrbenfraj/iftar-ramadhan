#!/usr/bin/env bash
# Prints the local Flutter Docker image for the version in .flutter-version,
# building it first if needed (~5 min, once per Flutter version).
#
#   img=$(apps/mobile/tool/flutter-image.sh)
#   MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/app" -w /app "$img" flutter analyze
#
# To upgrade Flutter: change .flutter-version (CI follows it too) and rerun.
set -euo pipefail

cd "$(dirname "$0")/.."
version="$(tr -d '[:space:]' < .flutter-version)"
image="iftar-flutter:$version"
if ! docker image inspect "$image" >/dev/null 2>&1; then
  echo "Building $image (once)..." >&2
  docker build --progress=plain --build-arg "FLUTTER_VERSION=$version" -t "$image" tool/docker >&2
fi
echo "$image"
