---
name: release-app
description: Release a new version of the Android app (bump version, merge, tag, publish), force an update, or roll back. Use when asked to release, ship, publish the APK, bump the app version, or cut v1.x.y.
---

# Releasing the app

Full reference: `docs/DEPLOYMENT.md` (§5 release, §7 minimum version,
§8 rollback). Key constraints:

- `main` is protected: no direct pushes, one approval from the other
  maintainer. Work on a branch and open a pull request. Before committing,
  check `git branch --show-current` is not `main`.
- Deploy secrets and variables live in the GitHub environment `production`,
  which only accepts runs from `main` and `v*.*.*` tags.
- A version can be published only once. Always bump; never re-tag.

## Steps

1. On a branch, set `version:` in `apps/mobile/pubspec.yaml` (e.g.
   `1.5.0+1`; only `x.y.z` matters, `versionCode` is computed from it).
   At the start of a new Ramadan, bump the major (`2.0.0`).
2. Commit, push, open a PR. Ask the user before merging; the other maintainer
   must approve.
3. After it is merged, tag the merged commit:

   ```bash
   git switch main && git pull
   git tag v1.5.0
   git push origin v1.5.0
   ```

   The tag must equal the pubspec version or the workflow stops. Pushing a tag
   publishes to every volunteer, so confirm with the user first.
4. The **Release app** workflow deploys the backend, builds the signed APK,
   publishes it and checks its SHA-256. Installed apps offer the update on
   their next start.

## Other operations (confirm with the user first; they affect volunteers)

- Force an update: Actions → **Set minimum app version** → e.g. `1.5.0`
  (`0.0.0` removes it).
- Roll back new downloads: `SERVER_HOST=<host> SSH_USER=ubuntu deploy/rollback-apk.sh 1.4.0`.
  Phones that already updated keep the newer version; to really undo, release
  a fixed `1.5.1`.

If `SERVER_HOST` in the `production` environment is empty or a placeholder,
there is no server: deploys skip or fail at SSH. That is expected outside
Ramadan.
