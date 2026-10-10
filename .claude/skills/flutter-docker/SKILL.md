---
name: flutter-docker
description: Run Flutter commands (analyze, gen-l10n, format, pub get, test, build apk) for apps/mobile in Docker. Use whenever a Flutter or Dart command is needed — the host has no Flutter or Android SDK.
---

# Flutter in Docker

The Windows host has no Flutter/Android SDK. Run everything from Git Bash in
the local `iftar-flutter:<version>` image, with the pub cache in a named volume
so only the first run downloads packages. `tool/flutter-image.sh` prints the
image name for the version pinned in `apps/mobile/.flutter-version` (the same
version CI uses), building it first if needed (~3 min, once per version).

```bash
cd apps/mobile
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$(pwd -W):/app" -v iftar_pub_cache:/root/.pub-cache -w /app \
  "$(tool/flutter-image.sh)" \
  sh -c "flutter gen-l10n && flutter analyze && dart format <changed files>"
```

- Don't use `ghcr.io/cirruslabs/flutter:stable` directly: cirruslabs stopped at
  Flutter 3.44.0. To upgrade Flutter, change `.flutter-version` only.

- `MSYS_NO_PATHCONV=1` and `$(pwd -W)` are required in Git Bash, otherwise the
  mount path is mangled. Docker Desktop must be running.
- Over the Windows bind mount `flutter analyze` takes ~6 min. Batch commands
  into one container run instead of starting several.
- Run `flutter gen-l10n` after editing any `lib/l10n/*.arb` file; the generated
  `app_localizations*.dart` files are committed.
- Run `dart format` on the files you changed and commit its output (it may
  reflow nearby lines too).

## APKs

Use the script, not `flutter build apk` over the mount. It builds in a
long-lived `iftar-apk-builder` container, so repeat builds take under a minute
(the first one ~10 min):

```bash
apps/mobile/tool/build-apk.sh development            # emulator / local backend
API_URL=https://<server> apps/mobile/tool/build-apk.sh production
```

Hand-built APKs are debug-signed unless `apps/mobile/android/key.properties`
exists. Never publish them: official releases come from the **Release app**
workflow (see the `release-app` skill).

## Verification policy

The maintainer does not want tests or e2e written or run by default. Verify
with `flutter analyze` (and `npm run lint` / `npm run build` for the backend).
