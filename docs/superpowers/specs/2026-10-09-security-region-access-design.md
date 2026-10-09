# Security fixes and region access control — design

Date: 2026-10-09 · Status: implemented on feat/security-region-access (2026-10-09) · Branch: `feat/security-region-access`

## 1. Goal

Make the backend safe to put on the internet before the January dry run and Ramadan 2027
(about 8 February). Today:

- any logged-in volunteer can read, edit, delete or serve people in **any** region by
  changing the region in the URL; `GET /fastings` returns everyone everywhere;
- anyone with the APK can register, pick any region and start at once;
- the JWT private key and the admin password are committed to a **public** repository;
- a disabled account keeps working until its token expires; there is no rate limiting.

Success: a volunteer can only act in their own region, new people get in only through a
region join code or an admin's approval, no secret lives in git, and a disabled account
stops working on its next request — without changing the API shape the current app uses.

Out of scope: meal review / regions admin screens (later admin-screens spec), soft delete
and audit log of people, a region switcher for global admins, rewriting git history.

Decisions taken with the user (2026-10-09):

- joining = region join code gives instant access; no code = admin approval;
- roles = global admin, regional admin, volunteer;
- enforcement = approach A (central region guard + fresh user lookup on every request);
- secrets = rotate and remove going forward; git history is not rewritten;
- a small in-app Volunteers screen for admins.

## 2. Roles and permissions (approved)

| | Volunteer (`USER`) | Regional admin (`REGION_ADMIN`) | Global admin (`ADMIN`) |
|---|---|---|---|
| Scan, serve, find, list, statistics | own region | own region | all regions |
| Add / edit people | own region, can't change a person's region | own region | all, can move a person |
| Delete people | ✗ | own region | all |
| Undo a meal | own meal within `UNDO_WINDOW_MINUTES` | any meal in region, until end of day | any |
| Meal review | ✗ | own region | all |
| Approve / refuse / disable / enable accounts | ✗ | own region, volunteers only | everyone; makes regional admins; moves users |
| Region join code: view / change / turn off | ✗ | own region | all |
| Create / edit / delete regions, `allowOfflineServing` | ✗ | ✗ | ✓ |
| List users | only `/users/me` | own region | all |

Cross-cutting rules:

- A disabled or pending account is refused on its next request, including refresh and
  offline sync. Offline meals queued by a user who is disabled later are refused by sync.
- A regional admin or volunteer with no region gets no access (fail closed).
- A region the caller may not access → **403** `REGION_FORBIDDEN`. A person who exists in
  another region → **404**, so ids cannot be probed.
- `GET /fastings` (all regions) becomes global-admin only.

## 3. Data model and enforcement (approved)

### 3.1 Migration

`users`:

- `roles` (simple-array) gains the value `REGION_ADMIN`.
- `isAccountDisabled` is replaced by `status` varchar: `pending | active | disabled`.
  Existing rows: `isAccountDisabled = true` → `disabled`, else `active`.
- `approvedByUserId` int null (no FK needed, matches `meal_events` style), `approvedAt`
  timestamptz null, `joinedWithCode` boolean default false.

`regions`:

- `joinCode` varchar(32) null, unique. Plain text (the coordinator must see and share it).
  Null = joining by code is off for this region. Existing regions start with null.

### 3.2 `AccessPolicy` — the single place rights are decided

`src/auth/access/access-policy.service.ts`, pure methods over the request user
`{ id, roles, regionId }`:

- `isGlobalAdmin(user)`.
- `canAccessRegion(user, regionId)`: global admin → true; otherwise
  `user.regionId != null && user.regionId === regionId`.
- `isRegionAdmin(user, regionId)`: global admin, or `REGION_ADMIN` with
  `canAccessRegion`.
- `canManageUser(actor, target)`: global admin → true; regional admin → only when the
  target is a plain `USER` of the actor's region; volunteer → false.

`FastingAclService` and `UserAclService` stop granting blanket `Manage` and delegate to
these methods (delete → `isRegionAdmin`; read/update → `canAccessRegion`).

### 3.3 `RegionAccessGuard`

`src/auth/guards/region-access.guard.ts`, runs after `JwtAuthGuard`:

- region comes from the `:region` route param; for `POST /fastings` from the body's
  `region` (a number in the current app);
- calls `canAccessRegion`; no → `ForbiddenException` with code `REGION_FORBIDDEN`;
- applied at `FastingController` class level; routes with no region opt out with
  `@SkipRegionCheck()` (`meals/:eventId/revoke`, `meals/sync`, `GET /fastings`), and those
  check in the service or by role;
- also applied to `GET /fastings/meals/review/:region` together with an
  `isRegionAdmin` check.

Id-based routes check in the service with the same `AccessPolicy`:

- revoke by `eventId`: load the meal → `canAccessRegion(meal.regionId)` → then the undo
  rule (owner within the window, or `isRegionAdmin` until end of day);
- offline sync: keeps its existing region check; a non-active user never reaches it;
- person by id: always looked up by `(region, id)`; not found → 404.

### 3.4 Fresh user on every request

`JwtAuthStrategy.validate()` and `JwtRefreshStrategy.validate()` load the user by
`payload.sub`:

- missing user → 401; `status = pending` → 401 `ACCOUNT_PENDING`;
  `status = disabled` → 401 `ACCOUNT_DISABLED`;
- `req.user = { id, username, roles, regionId }` taken from the database; the `roles`
  claim in the token is ignored.

The token shape is unchanged, so phones already logged in keep working.

### 3.5 Validation that comes with it

- `:region` and `:id` params get `ParseIntPipe`.
- `UpdateFastingInput.region` keeps its shape (the app sends the region object) but is
  validated as `{ id: int }`. If `region.id` differs from the URL region and the caller is
  not a global admin → 403 `REGION_FORBIDDEN`. A global admin moving a person needs
  `canAccessRegion` on the target region too (always true for them).
  *Deviation from the approved section 2, which proposed renaming it to `regionId`:
  keeping the shape avoids an app change and keeps older app versions working.*

## 4. Joining and approval (proposed)

### 4.1 Register — `POST /auth/register`

Body: `name, username, email, password` plus **either** `joinCode` **or** `region: {id}`.

- `joinCode` given: looked up case-insensitively, trimmed. Found and region active →
  user created `active`, `region` = the code's region, `joinedWithCode = true`; response
  says `status: active`. Not found → 400 `INVALID_JOIN_CODE` (no silent fallback to
  approval, so a typo is noticed).
- No code: `region` required and must be active → user created `pending`; response says
  `status: pending`.
- Both given: the code wins and `region` is ignored.
- Role is always `USER`. Password minimum becomes 8 for new accounts (existing passwords
  keep working).
- Public `GET /regions` returns only `{id, name}` of active regions (no join code, no
  `allowOfflineServing`, no creator).

### 4.2 Login

`LocalStrategy` returns 401 `ACCOUNT_PENDING` / `ACCOUNT_DISABLED` instead of the
current generic message, so the app can show the right screen.

### 4.3 Account endpoints (Volunteers screen)

All under `/users`, JWT required, permission per §2 via `canManageUser`:

| Method | Path | Who | Effect |
|---|---|---|---|
| GET | `/users?status=pending\|active\|disabled` | region admin (own region), global admin (all, optional `regionId`) | list `{id, name, username, email, roles, status, region, joinedWithCode, createdAt}` |
| POST | `/users/:id/approve` | `canManageUser`, target `pending` | `active`, set `approvedBy/At` |
| POST | `/users/:id/refuse` | `canManageUser`, target `pending` | delete the pending account (frees the username) |
| POST | `/users/:id/disable` | `canManageUser`, target `active`, not self | `disabled` |
| POST | `/users/:id/enable` | `canManageUser`, target `disabled` | `active` |
| PATCH | `/users/:id/role` | global admin only | body `{ role: USER\|REGION_ADMIN, regionId }`; also moves a user between regions |

`GET /users/:id` and `PATCH /users/:id` (existing) become global-admin only. Nobody can
disable or demote themselves, and the last active global admin cannot be disabled.

### 4.4 Join code endpoints

Under `/regions/:id/join-code`, `isRegionAdmin(regionId)`:

- `GET` → `{ joinCode }` (null when off);
- `POST` → generate a new code, replacing the old one, return it;
- `DELETE` → turn joining by code off.

Code format `WORD-1234`: a word from a short built-in list of easy Latin words (e.g.
`NOUR`, `RAHMA`, `SABR`, `BARAKA`) + 4 random digits from `crypto.randomInt`, retried on
the unique constraint. Accounts created with an old code stay active.

Region CRUD (`POST/PATCH/DELETE /regions`) and `allowOfflineServing` become global-admin
only.

## 5. Hardening (proposed)

### 5.1 Rate limiting

Re-enable `@nestjs/throttler` (already a dependency), keyed by client IP. Volunteers often
share one Wi-Fi or carrier IP at the distribution point, so normal routes get only a
generous backstop and the strict limits go on the auth routes:

- global backstop: 600 requests / minute / IP;
- `POST /auth/login`: 10 / minute / IP;
- `POST /auth/register`: 5 / 10 minutes / IP (also limits join-code guessing);
- `POST /auth/refresh-token`: 30 / minute / IP.

Express gets `trust proxy` set to 1 hop so the IP Caddy forwards is used, not Caddy's.
Over the limit → 429 `TOO_MANY_REQUESTS`.

### 5.2 CORS

The client is a native app and the `/download` page is same-origin, so `enableCors()` is
removed (no CORS headers at all). Adminer is a separate service and is unaffected.

### 5.3 Input limits

- `PaginationParamsDto.limit`: `@Max(500)` (the app loads lists 500 at a time).
- Meal counts `singleMeal`, `familyMeal`: `@IsInt() @Min(0) @Max(50)`.
- Person `id` (the number on the card): `@IsInt() @Min(1)`.
- The ineffective `@ValidateNested` on `takenMeals` dates is removed.

## 6. Secrets (proposed)

In the repo:

- `git rm` `apps/backend/.env`, `.env.development`, `.env.production`; `.gitignore` covers
  `apps/backend/.env*` except `.env.template`.
- `.env.template` keeps placeholders only (it already has no real values; DB user becomes
  `iftar`, not `root`).
- `setup.sh` stops writing secrets: it copies `.env.example`, generates a JWT key pair
  with the existing `scripts/generate-jwt-keys`, generates random `DB_PASS` and
  `DEFAULT_ADMIN_USER_PASSWORD` with `openssl rand`, and drops the personal e-mail
  (`ACME_EMAIL` stays a placeholder).
- `src/cli.ts` stops printing the admin password.
- The CLI gains a `reset-admin-password` argument (`npm run cli:prod -- reset-admin-password` on the server) that sets the `admin` user's password
  from `DEFAULT_ADMIN_USER_PASSWORD`, for a server that already exists.

Manual steps for the user, listed in `docs/DEPLOYMENT.md` (Claude does not touch GitHub
settings or the server):

1. generate a new JWT key pair, a new `DB_PASS` and a new admin password;
2. put them in the GitHub secrets the deploy workflow already reads;
3. if a server is running: redeploy (new keys log every phone out once), change the
   Postgres password, run `npm run cli:prod -- reset-admin-password`.

The old values remain in public git history but are useless once rotated.

## 7. CI gates (proposed)

Per the no-tests rule, release gates are build/lint/analyze only:

- `deploy-backend.yml`: `npm test` → `npm run lint && npm run build`.
- `release.yml` `test-mobile` job (renamed `check-mobile`): drop `flutter test`; keep
  `flutter analyze`. `analysis_options.yaml` excludes `test/**` so the stale tests no
  longer fail analysis. The test files are left in place.

## 8. Mobile app (proposed)

- **Register**: an optional "Join code" field above the region picker. When a code is
  typed, the region picker is hidden. `INVALID_JOIN_CODE` → field error "This code isn't
  valid. Check it with your coordinator." Response `pending` → a "Waiting for approval"
  page (who to contact, back to login); `active` → straight to login with the username
  filled.
- **Login**: `ACCOUNT_PENDING` → the same "Waiting for approval" page;
  `ACCOUNT_DISABLED` → "This account is disabled. Ask your coordinator."
- **Mid-session**: any 401 with `ACCOUNT_DISABLED` / `ACCOUNT_PENDING` logs the phone out
  with that message. Unsynced offline meals are dropped (sync would refuse them anyway);
  the existing logout wipe runs. `REGION_FORBIDDEN` shows the generic "You can't do this
  here" error.
- **Role**: `User` gains `isRegionAdmin`; the existing unused `isAdmin` starts being used.
  Delete on person details is shown to admins only.
- **Volunteers screen** — Profile → "Volunteers", visible to regional and global admins:
  - Join code card: the code in large letters, Share (share_plus, prefilled message),
    New code (confirm), Turn off (confirm).
  - Tabs Waiting / Active / Disabled with counts. Waiting rows: Approve, Refuse
    (confirm). Active rows: Disable (confirm). Disabled rows: Enable.
  - Global admin only: on a row, "Make coordinator" / "Make volunteer" and "Move to
    region"; a region filter at the top.
  - Uses the Maghrib light components (hairline rows, status chips); all strings in
    en / fr / ar.

## 9. Rollout

1. Backend first (migration runs in deploy). Existing accounts become `active`; existing
   regions have no join code, so until a coordinator creates one, new sign-ups wait for
   approval.
2. Then release the app. Older app versions keep working: API shapes are unchanged and
   the register body still accepts `region`. Raise the minimum version after the release
   so everyone gets the Volunteers screen and the new messages.
3. Before the dry run: the global admin makes each region's coordinator a regional
   admin and each coordinator creates their join code.

## 10. Verification

No automated tests (user preference). Per task: backend `npm run lint` and
`npm run build`, mobile `flutter analyze` in Docker. A manual check with `curl` against a
local backend for: cross-region read/serve/edit/delete → 403/404; register with and
without code; pending/disabled login; a disabled user's existing token → 401; regional
admin limits on `/users/*`; rate limit on login.
