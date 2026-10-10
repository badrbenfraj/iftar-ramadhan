# Deployment, releases and app updates

How the server, the Android APK and in-app updates fit together, and how to
bring everything back up next Ramadan. Written for someone who has never seen
this system, or has forgotten it since last year.

**The short version.** Each Ramadan: create an OVH server, put its hostname in
two GitHub settings, run one workflow, and send volunteers one link,
`https://<server>/download`. To release a new app version during Ramadan,
bump the version, push a tag, and installed apps offer the update by
themselves.

---

## 1. How it works

```
 GitHub Actions ──SSH──▶ OVH server  /opt/iftar/
                          ├── docker-compose.yml   Caddy + API + Postgres
                          ├── Caddyfile            HTTPS + routing
                          ├── .env                 written by the workflow
                          ├── apps/backend/        API source, built on the server
                          └── releases/
                              ├── app-1.4.0.apk
                              ├── app-1.5.0.apk    every release is kept
                              ├── latest.apk ──▶ app-1.5.0.apk   (symlink)
                              ├── latest.json      {"version","sha256",...}
                              └── minimum-version  "1.4.0"

 https://<server>/download          HTML page for volunteers   (API)
 https://<server>/releases/latest.apk  the newest APK          (Caddy, from disk)
 https://<server>/api/v1/app/version   what the app checks     (API)
 https://<server>/api/v1/...           the REST API            (API)
```

- **No server address in the code.** The APK learns its server from the
  build-time variable `API_URL` (`--dart-define=API_URL=https://<server>`),
  which GitHub Actions takes from the repository variable of the same name.
  The app appends `/api/v1` itself.
- **HTTPS** comes from Caddy, which gets and renews a free Let's Encrypt
  certificate for the server's OVH hostname (e.g. `vps-1a2b3c4d.vps.ovh.net`).
  No domain name to buy, no DNS to manage.
- **APKs live on the server's disk** in `/opt/iftar/releases/`. No object
  storage, no CDN: there are 5–10 volunteers.
- **Update check.** When the app starts (and when it comes back to the
  foreground after more than an hour), it calls `GET /api/v1/app/version`:

  ```json
  { "data": {
      "latestVersion": "1.5.0",
      "minimumVersion": "1.4.0",
      "downloadUrl": "/releases/latest.apk",
      "downloadPageUrl": "/download",
      "sha256": "9f2c…",
      "releasedAt": "2027-02-12T10:00:00Z" },
    "meta": {} }
  ```

  | Installed | latest | minimum | The app shows |
  |---|---|---|---|
  | 1.5.0 | 1.5.0 | 1.4.0 | nothing |
  | 1.4.0 | 1.5.0 | 1.4.0 | "A new version is available" with **Update** / **Later** |
  | 1.3.0 | 1.5.0 | 1.4.0 | a full "Update required" screen with only **Update** |

  **Update** opens `/download` in the phone's browser. If the server cannot be
  reached, the app simply carries on: an offline start is never blocked. The
  only thing that blocks the app is an explicit "your version is below
  `minimumVersion`". Versions are compared number by number (1.9.0 < 1.10.0).

  Code: `apps/mobile/lib/features/update/` (rules in `domain/`, unit-tested in
  `test/domain/update_rules_test.dart`) and `apps/backend/src/app-release/`.

---

## 2. GitHub configuration

Repository → **Settings → Environments → `production`**. The workflow jobs
that touch the server run in that environment, so its secrets and variables
are the only ones they read (do not also define them at repository level).
There are two lists. **Variables** are plain settings anyone with access can read.
**Secrets** are write-only: you can replace them but never see them again.

### Variables (not sensitive)

| Name | Example | Purpose |
|---|---|---|
| `SERVER_HOST` | `vps-1a2b3c4d.vps.ovh.net` | Server hostname. Used for SSH, for the HTTPS certificate, and as the default `API_URL`. **Delete it at the end of Ramadan**: while it is empty every deploy workflow skips itself. |
| `API_URL` | `https://vps-1a2b3c4d.vps.ovh.net` | Server the APK talks to (origin only, no `/api/v1`). Optional: defaults to `https://<SERVER_HOST>`. Must be `https://`. |
| `ACME_EMAIL` | `you@example.com` | Contact address for Let's Encrypt (expiry warnings). |
| `APP_TIMEZONE` | `Africa/Tunis` | Optional. Defines "today" for the one-meal-per-day rule. |
| `JWT_ACCESS_TOKEN_EXP_IN_SEC` / `JWT_REFRESH_TOKEN_EXP_IN_SEC` | `86400` / `2592000` | Optional. Session lifetimes (defaults: 1 day / 30 days). |
| `DB_NAME` / `DB_USER` | `iftar_db` / `iftar` | Optional. Only if an existing database was created with other names. |

### Secrets (sensitive)

| Name | What to put in it |
|---|---|
| `SSH_USER` | SSH login on the server, usually `ubuntu` on OVH. |
| `SSH_PRIVATE_KEY` | Private half of the deploy key (§3.2), the whole file including the `-----BEGIN…` lines. |
| `DB_PASS` | Postgres password. Any long random string. |
| `DEFAULT_ADMIN_USER_PASSWORD` | Password of the `admin` account created on first start. |
| `JWT_PUBLIC_KEY_BASE64` / `JWT_PRIVATE_KEY_BASE64` | Token signing keys (§3.3). |
| `ANDROID_KEYSTORE_BASE64` | The APK signing keystore, base64-encoded (§3.1). |
| `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_PASSWORD` | Its passwords. |
| `ANDROID_KEY_ALIAS` | Its key alias (e.g. `upload`). |

The old `VPS_HOST` / `VPS_USER` / `APP_PORT` / `DB_PORT` secrets used by the
previous workflow are no longer read and can be deleted.

---

## 3. One-time setup (keep these forever)

### 3.1 The APK signing key — do not lose it

Android only installs an update if it is signed with **the same key** as the
installed app. Lose the key and every volunteer has to uninstall and reinstall.
Create it once, store a copy in the association's password manager, and reuse
it every year.

No JDK needed, Docker is enough:

```bash
docker run --rm -it -v "$PWD:/out" ghcr.io/cirruslabs/flutter:stable \
  keytool -genkeypair -v -keystore /out/iftar-release.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Then fill the four secrets:

```bash
base64 -w0 iftar-release.jks   # → ANDROID_KEYSTORE_BASE64
```

`ANDROID_KEY_ALIAS` = `upload`, and the two passwords you typed
(`keytool` uses the store password for the key unless you chose another).
Never commit the `.jks` (it is git-ignored).

> Apps installed before this key existed were signed with a debug key. The
> first release signed with the real key cannot install over them: those
> phones must uninstall once and install from `/download`.

### 3.2 The deploy SSH key

A key pair used only by GitHub Actions:

```bash
ssh-keygen -t ed25519 -f iftar-deploy -N "" -C "github-actions iftar"
```

`iftar-deploy` (private) → secret `SSH_PRIVATE_KEY`.
`iftar-deploy.pub` (public) → added to the server (§4 step 1).

### 3.3 JWT keys

```bash
apps/backend/scripts/generate-jwt-keys
```

Paste the two printed values into the `JWT_*_BASE64` secrets **without the
surrounding quotes**. Changing them signs every volunteer out, nothing worse.

---

## 4. New Ramadan deployment (new server)

Assume nothing survives from last year except this repository and the GitHub
secrets.

1. **Create the server.** OVH → VPS → Ubuntu (latest LTS), smallest size is
   enough. At creation, add your own SSH public key **and**
   `iftar-deploy.pub`. (Forgot? `ssh ubuntu@<host>` then append it to
   `~/.ssh/authorized_keys`.) Note the hostname OVH gives it,
   e.g. `vps-1a2b3c4d.vps.ovh.net`.
2. **Check you can log in:** `ssh ubuntu@vps-1a2b3c4d.vps.ovh.net`. Ports 80
   and 443 must be reachable (they are on a fresh OVH VPS; if you enabled
   `ufw`, run `sudo ufw allow 22,80,443/tcp`).
3. **Update the GitHub variables:** `SERVER_HOST` = the new hostname. Set
   `API_URL` = `https://<new hostname>` (or delete it to use that default).
   Check `ACME_EMAIL` and that all secrets in §2 exist.
4. **Bump the app version** in `apps/mobile/pubspec.yaml` (e.g. `2.0.0`, see
   §9 for why) and commit it.
5. **Run the release:** Actions → **Release app** → *Run workflow* (leave
   "Deploy the backend first" ticked). It will:
   - run the app and backend tests;
   - install Docker on the new server (first time only), upload the stack,
     build and start it, and wait for HTTPS to work (the certificate takes up
     to a minute the first time);
   - build the signed APK with `API_URL` baked in, upload it, verify its
     SHA-256 on the server, publish it as `latest.apk`, then download it back
     over HTTPS and check the checksum again.
6. **Open `https://<new hostname>/download`** on a phone and install the app.
   Sign in as `admin` with `DEFAULT_ADMIN_USER_PASSWORD`, create the regions /
   volunteer accounts as usual.
7. **Send volunteers the one link:** `https://<new hostname>/download`.

Last year's APKs point at last year's server, which no longer exists. They
cannot reach the new server and cannot see the update; volunteers must install
from the new `/download` link (Android installs it over the old app because
the signing key and package name are the same, as long as the new version
number is higher).

---

## 5. Releasing a new version during Ramadan

1. Change `version:` in `apps/mobile/pubspec.yaml`, e.g. `1.5.0+1` (only
   `1.5.0` matters; the build number is computed from it).
2. Commit, then tag and push:

   ```bash
   git tag v1.5.0
   git push origin main v1.5.0
   ```

   (Or Actions → **Release app** → *Run workflow*, which uses the pubspec
   version.) The tag must match the pubspec version or the workflow stops.
3. Wait for the workflow to go green. Installed apps show "A new version is
   available" on their next start. Nothing else to do.

A version number can only be published once: re-publishing `1.5.0` with
different content is refused. Bump to `1.5.1` instead.

The release steps on the server (`deploy/server/publish-apk.sh`):
upload to `app-1.5.0.apk.tmp` → check SHA-256 → rename to `app-1.5.0.apk`
(atomic, same disk) → switch the `latest.apk` symlink with an atomic rename →
rewrite `latest.json` → `release-apk.sh` downloads `latest.apk` back over
HTTPS and compares checksums. A volunteer can never download a half-uploaded
file.

---

## 6. APK distribution

| URL | Who uses it |
|---|---|
| `https://<server>/download` | Volunteers (the only link they need). Shows the version, a big download button, and an install note in English, Arabic and French. |
| `https://<server>/releases/latest.apk` | The download button. Always the newest release; the URL never changes. Downloads as `iftar-saim.apk`. |
| `https://<server>/releases/app-1.5.0.apk` | A specific version (troubleshooting). |

First install on a phone: Android will ask to allow installing apps from the
browser (or file manager). Allow it, then open the downloaded file again.

Each release's checksum is in `latest.json`, in `app-<version>.apk.sha256` next
to the APK, shown at the bottom of `/download`, and in the workflow log. Every
built APK is also attached to its workflow run for 90 days.

---

## 7. Forcing an update (`minimumVersion`)

Use it when old versions must stop being used (e.g. an API change they cannot
handle). Release the fixed version first, then:

- **GitHub:** Actions → **Set minimum app version** → enter e.g. `1.5.0`.
- **Or from a laptop:**
  `SERVER_HOST=<host> SSH_USER=ubuntu deploy/set-minimum-version.sh 1.5.0`
- **Or on the server:** `echo 1.5.0 > /opt/iftar/releases/minimum-version`

It takes effect immediately (no restart): each app below that version shows
the "Update required" screen on its next start, or when it comes back to the
foreground after an hour. `0.0.0` removes the requirement. A minimum above the
latest published version is capped to the latest, so you cannot lock everyone
out by mistake.

---

## 8. Rolling back

```bash
SERVER_HOST=<host> SSH_USER=ubuntu deploy/rollback-apk.sh 1.4.0
```

This points `latest.apk` and `/download` back to `app-1.4.0.apk` (all old APKs
are kept). It only affects **new** downloads: Android refuses to install a
lower version over a higher one, so phones that already updated keep 1.5.0. To
really undo a bad release, revert the code and release it as `1.5.1`.

---

## 9. Versions across years

`versionCode` (what Android compares) is computed from the version:
`1.10.2` → `1010002`. Always increase the version, including at the start of a
new Ramadan, so the new APK installs over last year's app. Bumping the major
version each year (`2.0.0` for Ramadan 2028, …) keeps that obvious.

---

## 10. HTTPS

Nothing to configure by hand. Caddy (`Caddyfile`) requests a Let's Encrypt
certificate for `DOMAIN` (= `SERVER_HOST`) on first start and renews it. This
needs ports 80 and 443 open and the hostname resolving to the server, which
OVH hostnames do. If the first deployment fails at "Checking https://…", look
at `docker logs iftar-proxy` on the server; Caddy keeps retrying by itself, so
re-running the workflow a few minutes later is usually enough.

The app refuses plain HTTP in release builds (`usesCleartextTraffic` is only
enabled when `API_URL` is `http://`, i.e. local builds), and the release
workflow refuses an `API_URL` that is not `https://`.

---

## 11. Local development

**Backend** (details in the root `README.md`): Postgres in Docker, then
`npm run start:dev` in `apps/backend` → `http://localhost:3000`.

To try the update flow locally, put files in `apps/backend/releases/`
(git-ignored; the directory is `RELEASES_DIR`, default `releases`):

```bash
mkdir -p apps/backend/releases
echo '{"version":"9.0.0","sha256":null}' > apps/backend/releases/latest.json
echo 0.0.0 > apps/backend/releases/minimum-version
curl http://localhost:3000/api/v1/app/version
```

and open `http://localhost:3000/download` in a browser.

The dev server does not serve `/releases/*` files (Caddy does that in
production).

**App:** `API_URL` defaults to `http://localhost:3000`. The env files in
`apps/mobile/config/` set it for the emulator and the LAN:

```bash
flutter run --dart-define-from-file=config/development.json   # emulator → 10.0.2.2:3000
flutter run --dart-define=API_URL=http://192.168.1.20:3000      # phone on your Wi-Fi
```

A production-like APK by hand (no Flutter SDK needed, Docker only):

```bash
API_URL=https://<server> apps/mobile/tool/build-apk.sh production
```

It is signed with the debug key unless `apps/mobile/android/key.properties`
exists (format: see the "Install the release signing key" step in
`.github/workflows/release.yml`). Debug-signed APKs cannot update
release-signed installs, so publish only workflow-built APKs.

**Tests:** `flutter test` in `apps/mobile` (version comparison and update
rules: `test/domain/update_rules_test.dart`, `test/presentation/update_test.dart`),
`npm test` in `apps/backend` (`src/app-release/*.spec.ts`).

---

## 12. Deploying by hand (without GitHub Actions)

From Git Bash / Linux / macOS at the repository root, with your SSH key loaded:

```bash
cp .env.example .env.production          # fill in the values
export SERVER_HOST=vps-1a2b3c4d.vps.ovh.net SSH_USER=ubuntu
deploy/deploy-backend.sh .env.production
deploy/release-apk.sh path/to/app-release.apk 1.5.0
```

---

## 13. Day-to-day operations on the server

```bash
ssh ubuntu@<host>
cd /opt/iftar
docker compose ps                    # all containers "Up (healthy)"
docker compose logs -f app           # API logs
docker logs iftar-proxy              # HTTPS / certificate logs
ls -l releases/                      # APKs, latest.apk target, metadata
cat releases/latest.json releases/minimum-version
```

Database backup before tearing down (optional, if you want last year's
figures):

```bash
docker exec iftar-db pg_dump -U iftar iftar_db | gzip > iftar-$(date +%F).sql.gz
```

---

## 14. End of Ramadan

1. (Optional) back up the database (§13) and copy it off the server.
2. Delete the `SERVER_HOST` variable in GitHub, so pushes to `main` stop
   trying to deploy.
3. Delete the VPS in the OVH console.

Keep the GitHub secrets, above all the Android keystore ones, for next year.

## Rotating secrets (do this once now: old values are in public git history)

Old JWT keys, database and admin passwords were committed before October 2026. They
are useless once replaced:

1. New JWT pair: `cd apps/backend && ./scripts/generate-jwt-keys` → GitHub secrets
   `JWT_PUBLIC_KEY_BASE64`, `JWT_PRIVATE_KEY_BASE64`.
2. New `DB_PASS` and `DEFAULT_ADMIN_USER_PASSWORD` (`openssl rand -base64 24`) →
   GitHub secrets of the same name.
3. If a server is already running:
   - change the Postgres password:
     `docker exec -it iftar-db psql -U iftar -d iftar_db -c "ALTER USER iftar PASSWORD '<new>'"`
   - run the "Deploy backend" workflow (writes the new `.env`, restarts the API;
     every phone is signed out once because the JWT keys changed);
   - set the admin password: `docker exec iftar-app node dist/src/cli.js reset-admin-password`.
4. Locally: `apps/backend/.env*` are no longer tracked; copy `.env.template`.
