---
name: run-local
description: Start, stop or rebuild the local dev stack (Postgres + API + web app behind HTTPS) to test the app on this PC or a phone on the same Wi-Fi. Use when asked to run, start, test or preview the web app, the backend or "the app locally".
---

# Local stack (deploy/local)

Human-facing guide (new computer, phones, troubleshooting):
`docs/LOCAL_DEVELOPMENT.md`. Keep it in sync when changing the stack.

`deploy/local/compose.yml` runs the whole app like production: Postgres, the
API in watch mode (source bind-mounted) and Caddy serving the web app at
`/app/` with the API on the same HTTPS origin. Everything runs in Docker; the
host needs only Docker Desktop and Git Bash.

```bash
deploy/local/up.sh               # start (first run: generates .env, builds web, npm ci)
deploy/local/up.sh --build-web   # after changing Flutter code
deploy/local/up.sh down          # stop; data stays in Docker volumes
```

| What | Where |
|---|---|
| Web app (PC or iPhone on the Wi-Fi) | `https://<LAN_IP>:8443/app/` (`up.sh` prints it) |
| API | `http://localhost:3300/api/v1/health` |
| Adminer | `http://localhost:8081` (server `db`, user/password `iftar`) |
| Login | `admin` / `DEFAULT_ADMIN_USER_PASSWORD` in `deploy/local/.env` |

## Seed data (dev only)

The `seed` service runs `deploy/local/seed.sql` on every `up`, after the API is
healthy. It is idempotent (existing rows are kept). Password for all: `test-pass`.

| Account | Role / status | Region |
|---|---|---|
| `coord` | REGION_ADMIN | Dar Sokra |
| `vol1` | USER | Dar Sokra |
| `pending` | USER, pending approval | Dar Sokra |
| `off` | USER, disabled | Dar Sokra |
| `vol2` | USER | Dar Sousse |

Join codes: `NOUR-111111` (Dar Sokra), `RAHMA-222222` (Dar Sousse). Fasting
people: IDs 1-40 (Dar Sokra) and 101-115 (Dar Sousse), none served yet; serve
meals through the app so `meal_events` stays consistent. Re-run by hand with
`docker compose -f deploy/local/compose.yml run --rm seed`.

Never add seed data to the root `docker-compose.yml` or `apps/backend`: those
are deployed. `deploy/local/` is not shipped by `deploy/deploy-backend.sh`, and
the Deploy backend workflow ignores changes to it.

## Why it is set up this way

- **HTTPS is required.** On web the app keeps the login token in
  `flutter_secure_storage`, which only works in a secure context (HTTPS or
  `localhost`). Over plain `http://<LAN_IP>` login returns 200 but the app
  throws and never opens the list. Caddy issues its own certificate
  (`tls internal`); accept the browser warning once per device.
- **Same origin, no CORS.** The API sends no CORS headers (on purpose), so
  the app must be served by the same host as `/api`. Never point a web build
  at `:3300` directly.
- **The API address is compiled in.** `up.sh` rebuilds the web app when the
  LAN IP changes (stored in `apps/mobile/build/web/.lan_ip`). Override with
  `LAN_IP=192.168.x.y deploy/local/up.sh`.
- Clients send no SNI for a bare IP, hence `default_sni` in
  `deploy/local/Caddyfile`.

## Notes

- Backend edits reload automatically (`npm run start:dev`). After pulling new
  migrations, restart the API: `docker compose -f deploy/local/compose.yml restart api`.
- Logs: `docker compose -f deploy/local/compose.yml logs -f api`.
- The first API start runs `npm ci`, migrations and the CLI seed (admin +
  regions); allow a minute before `/health` answers (502 until then).
- APK builds for this stack use `config/local.json` (`API_URL` =
  `http://<LAN_IP>:3300`); see the `flutter-docker` skill.
- Fresh database: `deploy/local/up.sh down` then
  `docker volume rm iftar-local_db_data`. Ask the user first: it deletes the
  local test data.
