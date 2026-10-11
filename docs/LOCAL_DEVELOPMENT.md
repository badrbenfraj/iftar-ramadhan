# Local development

How to get the whole project running on a new computer, test it on a phone,
and build an APK, with **only Docker installed**. For the production server
and releases, see [DEPLOYMENT.md](DEPLOYMENT.md).

---

## 1. Install (once per computer)

| Tool | Notes |
|---|---|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Must be running. On Linux, Docker Engine + the Compose plugin. |
| [Git](https://git-scm.com/) | On Windows, use **Git Bash** for every command in this guide (it comes with Git for Windows). |

That's all. Node, Flutter, the Android SDK and Postgres all run in containers.
(Installing Node 24 or Flutter natively also works; see the
[root README](../README.md) for the native commands.)

```bash
git clone https://github.com/badrbenfraj/iftar-ramadhan.git
cd iftar-ramadhan
```

## 2. Start the stack

```bash
deploy/local/up.sh
```

The first run takes about 10 minutes; later starts take seconds. It:

1. finds this computer's LAN IP (override with `LAN_IP=192.168.x.y deploy/local/up.sh`);
2. creates `deploy/local/.env` with dev-only JWT keys and the admin password
   (git-ignored, never used in production);
3. builds the Flutter image pinned by `apps/mobile/.flutter-version` (once per
   Flutter version) and the web app;
4. starts [deploy/local/compose.yml](../deploy/local/compose.yml):

| Service | What | Address |
|---|---|---|
| `db` | PostgreSQL 16 | inside Docker only |
| `api` | NestJS API in watch mode (`apps/backend` is mounted: edits reload) | `http://localhost:3300/api/v1/health` |
| `seed` | Loads the test data below, then exits | — |
| `web` | Caddy: the web app at `/app/` and the API on one HTTPS origin, like production | `https://<LAN_IP>:8443/app/` |
| `adminer` | Database browser (server `db`, user and password `iftar`) | `http://localhost:8081` |

The API answers `502` for about a minute after the first start (it runs
`npm ci`, the migrations and the setup CLI).

Other commands:

```bash
deploy/local/up.sh --build-web                          # after changing Flutter code
deploy/local/up.sh down                                 # stop; data is kept
docker compose -f deploy/local/compose.yml logs -f api  # API logs
docker compose -f deploy/local/compose.yml restart api  # after pulling new migrations
```

## 3. Test data

Created by the setup CLI (`admin`) and by
[deploy/local/seed.sql](../deploy/local/seed.sql) (the rest). It runs on every
start and never overwrites existing rows. **Dev only**: `deploy/local/` is not
deployed and changes to it don't trigger the deploy workflow.

| Login | Password | Role | Region |
|---|---|---|---|
| `admin` | `admin-test-pass` | Admin (all regions) | Dar Sokra |
| `coord` | `test-pass` | Region coordinator | Dar Sokra |
| `vol1` | `test-pass` | Volunteer | Dar Sokra |
| `vol2` | `test-pass` | Volunteer | Dar Sousse |
| `pending` | `test-pass` | Volunteer waiting for approval (login refused) | Dar Sokra |
| `off` | `test-pass` | Disabled volunteer (login refused) | Dar Sokra |

- Join codes for registration: `NOUR-111111` (Dar Sokra), `RAHMA-222222` (Dar Sousse).
- Fasting people: IDs **1–40** in Dar Sokra, **101–115** in Dar Sousse, none
  served yet. Serve meals through the app.

Start over with an empty database (deletes all local data):

```bash
deploy/local/up.sh down
docker volume rm iftar-local_db_data
deploy/local/up.sh
```

## 4. Use the app

### In a browser, or on an iPhone

Open `https://<LAN_IP>:8443/app/` (the address `up.sh` prints) on this
computer or on any phone on the same Wi-Fi. The certificate is Caddy's own, so
accept the warning once per device ("Advanced → Proceed"; on iPhone "Show
Details → visit this website").

Why HTTPS and why this address: on the web the app stores the login session in
secure storage, which browsers only allow over HTTPS (or `localhost`); over
plain `http://<ip>` login returns 200 but the app fails right after. And the
API sends no CORS headers, so the app must be served from the same origin as
`/api`. Don't point a web build at `:3300`.

### On an Android phone

Build a debug APK that talks to this computer's API on port 3300:

```bash
API_URL=http://<LAN_IP>:3300 apps/mobile/tool/build-apk.sh local
# → apps/mobile/build/iftar-local.apk  (first build ~10 min, then under a minute)
```

Install it on a phone on the same Wi-Fi (copy the file, or
`adb install apps/mobile/build/iftar-local.apk`). Hand-built APKs are
debug-signed: never send them to volunteers; real releases come from GitHub
Actions ([DEPLOYMENT.md §5](DEPLOYMENT.md)).

### Android emulator

`config/development.json` points at `http://10.0.2.2:3000` (the host as seen
from the emulator). With this stack the API is on port 3300, so use
`API_URL=http://10.0.2.2:3300 apps/mobile/tool/build-apk.sh development`.

## 5. Flutter and Node commands without installing them

```bash
# Flutter (analyze, gen-l10n, format...), from apps/mobile
cd apps/mobile
MSYS_NO_PATHCONV=1 docker run --rm \
  -v "$(pwd -W 2>/dev/null || pwd):/app" -v iftar_pub_cache:/root/.pub-cache -w /app \
  "$(tool/flutter-image.sh)" sh -c "flutter analyze"

# Backend (lint, build, new migration), inside the running API container
docker compose -f deploy/local/compose.yml exec api npm run lint
docker compose -f deploy/local/compose.yml exec api npm run migration:generate --name=AddSomething
```

`MSYS_NO_PATHCONV=1` and `pwd -W` keep Git Bash from mangling paths on
Windows; they are harmless elsewhere.

## 6. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `port is already allocated` | Something else uses 3300, 8443 or 8081 (often an old container: `docker ps`). Stop it. |
| API `502` | Still starting; watch `docker compose -f deploy/local/compose.yml logs -f api`. |
| Browser: "connection reset" on `https://<ip>:8443` | The Wi-Fi IP changed. Run `deploy/local/up.sh` again: it rebuilds the web app for the new IP. |
| Login says OK but the app stays on the login screen | Opened over `http://`. Use the `https://…:8443/app/` address. |
| Phone can't reach the computer | Same Wi-Fi? Windows firewall: allow Docker Desktop on private networks. |
| `Could not find the LAN IP` | Pass it: `LAN_IP=192.168.x.y deploy/local/up.sh`. |
| Line-ending errors in shell scripts (`$'\r': command not found`) | The repo's `.gitattributes` keeps scripts LF; re-checkout with `git checkout -- <file>` if an editor converted them. |
