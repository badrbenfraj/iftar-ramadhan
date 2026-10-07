# إفطار صائم — Iftar Saim

Volunteer app for Ramadan iftar distribution. Volunteers scan a beneficiary's
QR card, see how many meals to hand over, and confirm the pickup. The server
guarantees **one meal per person per day**, even when several phones scan the
same card at the same time.

## Monorepo layout

```
/
├── apps/
│   ├── mobile/          Flutter app (Android + iOS): the new client
│   ├── backend/         NestJS 12 REST API + PostgreSQL (TypeORM 1.x)
│   └── legacy-ionic/    Previous Ionic 7 / Angular 16 app (kept until the Flutter app is validated in the field)
├── packages/            Shared Dart packages (none yet, see packages/README.md)
├── docs/
│   ├── DEPLOYMENT.md           Server, releases, in-app updates, yearly redeployment
│   ├── MIGRATION_ANALYSIS.md   Pre-migration analysis of the Ionic app and the API
│   └── MIGRATION_REPORT.md     What changed, why, what's left
├── deploy/              SSH scripts used by GitHub Actions (or by hand)
├── docker-compose.yml   Production stack: Caddy (TLS + APK files) + API + Postgres + Adminer
└── Caddyfile
```

## Requirements

| Tool | Version |
|---|---|
| Flutter | 3.44+ (Dart 3.12+) |
| Node.js | 24 LTS |
| PostgreSQL | 16 (or Docker) |
| Android | SDK 36 via Android Studio; JDK 17 |
| iOS | Xcode 16+ on macOS |

No local Flutter/Android SDK? Every Flutter command below also runs in Docker:

```bash
docker run --rm -v "$PWD:/repo" -w /repo/apps/mobile ghcr.io/cirruslabs/flutter:stable \
  sh -c "flutter pub get && flutter test"
```

## Backend (`apps/backend`)

```bash
# 1. Database
docker run -d --name iftar-db -p 5432:5432 \
  -e POSTGRES_USER=iftar -e POSTGRES_PASSWORD=iftar -e POSTGRES_DB=iftar_db postgres:16-alpine

# 2. Configuration
cd apps/backend
cp .env.template .env            # set DB_*, APP_PORT, DEFAULT_ADMIN_USER_PASSWORD
./scripts/generate-jwt-keys      # paste JWT_PUBLIC_KEY_BASE64 / JWT_PRIVATE_KEY_BASE64 into .env

# 3. Install, migrate, seed (admin user + default regions), run
npm install
npm run migration:run
npm run cli:dev
npm run start:dev                # http://localhost:3000/api/v1  (health: /api/v1/health)
```

| Command | What it does |
|---|---|
| `npm run build` / `npm run start:prod` | Compile to `dist/` and run it |
| `npm test` | Unit tests (Jest 30) |
| `npm run test:e2e` | E2E tests against Postgres (reads `DB_HOST`, `DB_USER`, `DB_PASS`, and creates/drops `e2e_test_db`) |
| `npm run lint` | ESLint 10 (flat config) |
| `npm run migration:generate --name=X` | New migration from entity changes |

### Backend environment

| Variable | Purpose |
|---|---|
| `APP_ENV` | `development` \| `production` \| `test` |
| `APP_PORT` | HTTP port (container: 3000) |
| `APP_TIMEZONE` | **Defines "today" for the one-meal-per-day rule** and statistics. Default `Africa/Tunis` |
| `DB_HOST` `DB_PORT` `DB_NAME` `DB_USER` `DB_PASS` | PostgreSQL |
| `JWT_PUBLIC_KEY_BASE64` `JWT_PRIVATE_KEY_BASE64` | RS256 key pair (base64 PEM) |
| `JWT_ACCESS_TOKEN_EXP_IN_SEC` `JWT_REFRESH_TOKEN_EXP_IN_SEC` | Token lifetimes |
| `DEFAULT_ADMIN_USER_PASSWORD` | Password of the seeded `admin` user |
| `RELEASES_DIR` | Directory with the APKs and release metadata (default `releases`; `/srv/releases` in Docker) |

### Production

**See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)**: GitHub Variables and Secrets,
releasing a new app version, the `/download` page, forcing an update, and the
step-by-step guide for a new OVH server each Ramadan.

In short: GitHub Actions deploys the root `docker-compose.yml` to
`/opt/iftar` on the server over SSH. The backend image
(`apps/backend/Dockerfile`, Node 24) is built there, runs the migrations, then
the seed CLI, then the API, behind Caddy with automatic Let's Encrypt HTTPS for
the OVH hostname. Caddy also serves the APKs from `/opt/iftar/releases`.

> Deploy the backend **before** shipping the Flutter app: the app relies on
> `409 MEAL_ALREADY_TAKEN`, the `mealTakenToday` flag and ISO dates in
> statistics. The legacy Ionic app keeps working against the new backend.

## Mobile app (`apps/mobile`)

```bash
cd apps/mobile
flutter pub get

# Run against a local backend (Android emulator reaches the host at 10.0.2.2)
flutter run --dart-define-from-file=config/development.json

# Run against production
flutter run --dart-define-from-file=config/production.json
```

Environment files live in `apps/mobile/config/`:

| Key | Meaning |
|---|---|
| `API_URL` | Server origin, e.g. `https://vps-xxxx.vps.ovh.net` (the app adds `/api/v1`). Default `http://localhost:3000`. Never committed for production: the release workflow passes the `API_URL` GitHub variable. |
| `APP_ENV` | `development` shows the API URL on the profile screen |

For a physical phone on your Wi-Fi, pass
`--dart-define=API_URL=http://<your-pc-ip>:3000` (or copy `development.json`).
Cleartext HTTP is only allowed when `API_URL` is `http://` or in debug builds.

### Quality checks

```bash
flutter analyze
flutter test                       # unit + widget tests (API mocked)

# Full-stack contract test against a running backend (creates, then deletes, one test person)
flutter test test/integration \
  --dart-define=IT_API_BASE_URL=http://localhost:3000/api/v1 \
  --dart-define=IT_USERNAME=<volunteer> --dart-define=IT_PASSWORD=<password>
```

### Build

Official APKs are built, signed and published by the **Release app** GitHub
workflow (push a tag `v<version>`, see [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)).
By hand:

```bash
# Android
flutter build apk --release --dart-define-from-file=config/production.json   --dart-define=API_URL=https://<server>
# → build/app/outputs/flutter-apk/app-release.apk

# iOS (macOS + Xcode)
flutter build ipa --release --dart-define-from-file=config/production.json   --dart-define=API_URL=https://<server>
```

Release builds use the release key from `android/key.properties` when present
(the workflow writes it from GitHub secrets), otherwise the debug key.

The app checks `/api/v1/app/version` at startup and offers (or, below the
minimum version, requires) an update through the server's `/download` page
(`lib/features/update/`).

### Architecture in one paragraph

Feature-first folders (`lib/features/{auth,people,scan,statistics,profile}`),
each split into `domain/` (pure Dart models and rules), `data/` (Dio
repositories behind interfaces) and `presentation/` (widgets + Riverpod 3
notifiers). `lib/core` holds config, networking (auth interceptor with
transparent token refresh, typed `AppFailure` errors), secure session storage,
the "Ramadan night" theme tokens and the router (go_router, auth-aware
redirects). See `docs/MIGRATION_REPORT.md` for details.

## Legacy Ionic app (`apps/legacy-ionic`)

Unchanged apart from its location. It works against the upgraded backend (a
second confirmation on the same day is now rejected, as intended).

```bash
cd apps/legacy-ionic && npm install && npm start
```

Remove it once the Flutter app has been validated during a real distribution.
