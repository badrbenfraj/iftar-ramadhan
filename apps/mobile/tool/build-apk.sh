#!/usr/bin/env bash
# Fast APK build in Docker (no Flutter/Android SDK needed on the host).
#
#   apps/mobile/tool/build-apk.sh [env] [out.apk]
#     env      config/<env>.json to build with (default: production)
#     out.apk  where to copy the APK (default: build/iftar-<env>.apk)
#
#   API_URL=https://vps-xxxx.vps.ovh.net apps/mobile/tool/build-apk.sh production
#     API_URL (server origin) overrides the env file; production needs it.
#     Official releases are built by GitHub Actions (docs/DEPLOYMENT.md).
#
# Speed: builds run in one long-lived container (iftar-apk-builder), so the
# Gradle daemon stays warm and build outputs are reused between runs. Sources
# are synced into the container instead of building over the slow Windows bind
# mount; pub/Gradle/Android SDK live in named volumes. Targets arm64 only (all
# modern phones). Stop it with: docker rm -f iftar-apk-builder
#
# Flutter version: the one in .flutter-version, the same as CI (image built by
# tool/flutter-image.sh).
#
# Size: only arm64 native libraries are packaged (see android/app/build.gradle.kts)
# and Dart debug symbols are split out to build/symbols-<env>, which is what
# `flutter symbolize` needs to read a crash stack trace from this APK.
set -euo pipefail

env="${1:-production}"
cd "$(dirname "$0")/.."
out="${2:-build/iftar-$env.apk}"
[ -f "config/$env.json" ] || { echo "config/$env.json not found" >&2; exit 1; }
api_define=""
if [ -n "${API_URL:-}" ]; then api_define="--dart-define=API_URL=$API_URL"
elif [ "$env" = production ]; then echo "Set API_URL=https://<server> for a production build" >&2; exit 1; fi

image="$(tool/flutter-image.sh)"
src="$(pwd)"
command -v cygpath >/dev/null && src="$(cygpath -w "$src")"
mkdir -p "$(dirname "$out")"

name=iftar-apk-builder
# Recreate the container when it is stopped, belongs to another checkout or
# runs another Flutter version.
key="$src@$image"
if [ "$(docker inspect -f '{{.State.Running}} {{index .Config.Labels "iftar.key"}}' "$name" 2>/dev/null)" != "true $key" ]; then
  docker rm -f "$name" >/dev/null 2>&1 || true
  MSYS_NO_PATHCONV=1 docker run -d --name "$name" --label "iftar.key=$key" \
    -v "$src":/src \
    -v iftar_pub_cache:/root/.pub-cache \
    -v iftar_gradle_cache:/root/.gradle \
    -v iftar_android_sdk:/opt/android-sdk-linux \
    "$image" sleep infinity >/dev/null
fi

MSYS_NO_PATHCONV=1 docker exec "$name" sh -c "
  set -e
  mkdir -p /work/android && cd /work
  # Mirror /src, keeping build outputs so Gradle and Flutter build incrementally.
  find . -mindepth 1 -maxdepth 1 ! -name build ! -name .dart_tool ! -name android -exec rm -rf {} +
  find android -mindepth 1 -maxdepth 1 ! -name .gradle -exec rm -rf {} +
  (cd /src && tar --exclude=./build --exclude=./.dart_tool --exclude=./android/.gradle -cf - .) | tar -xf -
  flutter build apk --release --target-platform android-arm64 \
    --split-debug-info=build/symbols \
    --dart-define-from-file=config/$env.json $api_define
  cp build/app/outputs/flutter-apk/app-release.apk /src/.build-apk.tmp
  mkdir -p /src/build && rm -rf /src/build/symbols-$env && cp -r build/symbols /src/build/symbols-$env
"
mv .build-apk.tmp "$out"
echo "APK: $out ($(du -h "$out" | cut -f1))"
