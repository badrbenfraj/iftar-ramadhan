# Local Flutter build image, built by tool/flutter-image.sh. cirruslabs stopped
# publishing new Flutter versions, so its image only provides Java and the
# Android SDK; the Flutter SDK is replaced by the version in .flutter-version
# (the same file CI reads), so local and CI builds match.
FROM ghcr.io/cirruslabs/flutter:3.44.0

ARG FLUTTER_VERSION

# The Flutter SDK is a git checkout and its tool runs git on startup.
RUN apt-get update \
 && apt-get install -y --no-install-recommends git xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && git config --system --add safe.directory '*'

RUN rm -rf /sdks/flutter \
 && curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    | tar -xJ -C /sdks \
 && flutter config --no-analytics >/dev/null \
 && flutter precache --android --no-ios --no-web --no-linux --no-windows --no-macos --no-fuchsia \
 && flutter --version | head -1 | grep -q "Flutter ${FLUTTER_VERSION} "
