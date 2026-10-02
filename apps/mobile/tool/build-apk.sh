#!/usr/bin/env bash
# Fast APK build in Docker (no Flutter/Android SDK needed on the host).
#
#   apps/mobile/tool/build-apk.sh [env] [out.apk]
#     env      config/<env>.json to build with (default: production)
#     out.apk  where to copy the APK (default: build/iftar-<env>.apk)
#
# Speed: sources are copied into the container instead of building over the
# Windows bind mount, and pub/Gradle/Android SDK live in named volumes, so only
# the first run downloads anything. Targets arm64 only (all modern phones).
set -euo pipefail

env="${1:-production}"
cd "$(dirname "$0")/.."
out="${2:-build/iftar-$env.apk}"
[ -f "config/$env.json" ] || { echo "config/$env.json not found" >&2; exit 1; }

src="$(pwd)"
command -v cygpath >/dev/null && src="$(cygpath -w "$src")"
mkdir -p "$(dirname "$out")"

MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$src":/src \
  -v iftar_pub_cache:/root/.pub-cache \
  -v iftar_gradle_cache:/root/.gradle \
  -v iftar_android_sdk:/opt/android-sdk-linux \
  ghcr.io/cirruslabs/flutter:stable sh -c "
    set -e
    mkdir /work && cd /src
    tar --exclude=./build --exclude=./.dart_tool --exclude=./android/.gradle -cf - . | tar -xf - -C /work
    cd /work
    flutter build apk --release --target-platform android-arm64 \
      --dart-define-from-file=config/$env.json
    cp build/app/outputs/flutter-apk/app-release.apk /src/.build-apk.tmp
  "
mv .build-apk.tmp "$out"
echo "APK: $out"
