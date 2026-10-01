# Migration report: Ionic/Angular → Flutter

Companion to [MIGRATION_ANALYSIS.md](MIGRATION_ANALYSIS.md), which was written before any change.

## 1. What the original project revealed

- **The product** is a volunteer tool for iftar distribution. Each beneficiary has a numeric
  QR card and an allotment of *single* and *family* meals (a family meal counts as 4 portions).
  Volunteers are scoped to a region.
- **The core rule, "one meal per person per day", was enforced only in the UI.** The confirm
  endpoint appended today's date to a client-supplied history. Two phones or a double tap
  could both confirm, and stale clients could overwrite the history.
- **Other backend defects:**
  - Adding a person with an existing ID silently overwrote that person.
  - "Daily" statistics always showed 0, because the end day was excluded and days were bucketed
    in UTC.
  - `/users/me` and every person response leaked bcrypt password hashes.
  - `GET/PATCH /users/:id` needed no authentication, so anyone could change any user's
    password.
- **Legacy client issues:** a JWT in `localStorage`, no token refresh, an export saved where
  users can't reach it, dead features (bulk mode, password reset, verify email), and
  "invalid QR" not distinguished from "person not found".

## 2. Architecture chosen and why

| Concern | Choice | Why |
|---|---|---|
| Structure | Feature-first; `domain` / `data` / `presentation` per feature, plus `core` | Business rules (QR parsing, meal allotment, periods, "taken today") are pure Dart and unit-tested without Flutter |
| State + DI | `flutter_riverpod` 3 (`Notifier` / `AsyncNotifier`, providers as the DI container) | Compile-safe, overridable in tests (fake repositories, fixed clock); no code generation |
| Navigation | `go_router` 17, `StatefulShellRoute` for the tabs, a pure `authRedirect` function | Keeps per-tab state like Ionic tabs; the redirect logic is unit-tested |
| HTTP | `dio` + `AuthInterceptor` (queued): bearer token, **one transparent refresh on 401**, then sign-out | Volunteers are not logged out mid-distribution |
| Errors | Sealed `AppFailure` hierarchy mapped from the API error envelope (`details.code`) | Screens switch on type: offline / timeout / server / not found / `MEAL_ALREADY_TAKEN` / `PERSON_ID_TAKEN` |
| Credentials | `flutter_secure_storage` (Keystore/Keychain) | Replaces plaintext `localStorage` |
| Scanner | `mobile_scanner` 7 (CameraX + ML Kit / AVFoundation), QR only | Continuous in-app camera instead of one native activity per scan |
| Config | `--dart-define-from-file=config/{development,production}.json` | No secrets in code; one build per environment |
| Export | `excel` + `share_plus` + `path_provider` | Same xlsx content, now opened in the share sheet |

**Dependencies:** 9 runtime packages, all required by a feature above. Dev dependencies are
`flutter_lints` only; the test fakes are hand-written.

### The scan workflow

`ScanController` is a pure state machine
(`Idle → LookingUp → Ready | AlreadyTaken | NotFound | InvalidCode | Failed → Confirming → Confirmed`).

- **Throughput:** the camera stays open. **"Confirm & scan next"** is one tap. After
  "Meal confirmed" the scanner resumes by itself after 1.6 s. A "Served this session" counter,
  torch, and manual ID entry (damaged card or camera denied) are available.
- **Safety:**
  - While a person is awaiting confirmation, the camera ignores other cards, so a volunteer
    can't lose a pending confirmation.
  - A card held in view is not re-read.
  - A confirm that timed out is retried safely: if the server had already committed, the
    resulting 409 is recognized as *our own* confirmation (within 3 minutes), not a second
    pickup.
  - Failed confirmations say explicitly: *"retry, do not serve twice"*.
- **Clarity:** each outcome has its own color, icon, and wording. Invalid QR and not-found are
  distinct, and not-found offers **Register** with the ID prefilled. There are also haptics per
  outcome.

## 3. What was migrated

| Ionic screen / feature | Flutter |
|---|---|
| Home (logo, Sign in / Sign up) | `WelcomePage` (+ `SplashPage` while the session is restored) |
| Login, Registration (region picker) | `LoginPage`, `RegisterPage`: same fields and messages; password rule aligned with the backend (≥ 6) |
| Tabs + center camera FAB in a notch | `HomeShell`: `BottomAppBar` + `CircularNotchedRectangle`; the bar hides while the keyboard is open, like Ionic |
| List + search + pull to refresh | `PeopleListPage`: search by name (either order), ID, CIN, phone; "N registered · M served today" |
| Person details, inline phone/comment edit, meal history sheet, Confirm Meal | `PersonDetailsPage` |
| Edit / delete person (confirmation alert) | `EditPersonPage` (ID read-only) |
| Add person (all fields, CIN = 8, meal rule, "Came today") | `AddPersonPage` |
| Scan → details → "Confirm and scan another code" | `ScanPage` + `ScanResultPanel` (see above) |
| Statistics (Daily/Weekly/Monthly/Custom, From/To, "Choose another period") | `StatisticsPage` + summary card |
| Profile, xlsx export, logout | `ProfilePage` |
| Theme: teal `#43CEBB`, ivory background, pill inputs/buttons, calligraphy logo, Arabic status words | Kept, with the "Ramadan night" evolution (below) |
| App name إفطار صائم, launcher icon | Android label + the Ionic mipmaps; iOS display name |

## 4. What was intentionally changed

**Visual (agreed during the migration):** a Ramadan-night identity. Deep indigo sky with a
painted crescent and stars, lantern-gold accents, the calligraphy tinted gold, warm ivory
surfaces. The teal primary and the Ionic pill shapes are unchanged. The design tokens live in
`lib/core/theme/app_colors.dart`.

**Behavior:**
- **Status badge colors are now semantic:** `خذا` (already taken) is **red** and `ما خذاش` is
  **green**. Ionic used the reverse, which made "already collected" look like a go-ahead.
- Invalid QR vs person not found are separate outcomes.
- Session: transparent token refresh; a cached profile allows offline startup.
- Export opens the share sheet instead of writing to an inaccessible folder.
- Dropped the dead features (bulk mode, password reset, verify email).
- Application ID `org.iftarramadhan.iftar_mobile` (new), so Ionic and Flutter can be installed
  side by side during validation.

**Backend (only where necessary, all compatible with the legacy Ionic app):**
- Confirm is atomic: `SELECT … FOR UPDATE` in a transaction plus a server-side "today" check
  in `APP_TIMEZONE` (default `Africa/Tunis`). The history is appended server-side; the client
  list is ignored. A second confirmation returns **409 `MEAL_ALREADY_TAKEN`**. Verified with
  25 concurrent requests: exactly 1 succeeded.
- `POST /fastings` returns **409 `PERSON_ID_TAKEN`** instead of overwriting.
- `POST /fastings` with "Came today" unchecked no longer records a fake meal dated yesterday,
  which showed up in the history and inflated yesterday's statistics. The person now starts
  with `takenMeals: []` and `lastTakenMeal: null`. Migration
  `1790850000000-MakeLastTakenMealNullable` drops the `NOT NULL` (it runs on container start).
  The legacy Ionic scan and details pages were patched to treat `null` as "not taken".
  **Ionic builds installed before that patch** show such a person as already taken, with no
  confirm button, until their first meal is confirmed from another device.
- Person responses gain `mealTakenToday` and `cin`, and no longer include `createdBy` (which
  leaked the password hash). `/users/*` responses no longer include password hashes.
- Statistics: inclusive end day, days in `APP_TIMEZONE`, each person counted once per day,
  and ISO `YYYY-MM-DD` accepted alongside the legacy `toDateString` format.
- `GET/PATCH /users/:id` now require an ADMIN token.
- **Upgraded, as you asked:** Node 24, NestJS 10 → 12, TypeORM 0.3 → 1.1, TypeScript 5 → 6
  (7 isn't supported by the Nest CLI or ts-jest yet), Jest 30, ESLint 10 (flat config). `uuid`
  was replaced by `crypto.randomUUID()`. Legacy unit/e2e specs that had drifted from the code
  were repaired.

## 5. Verification performed

| Check | Result |
|---|---|
| Backend build / lint / typecheck | ✅ clean |
| Backend unit tests | ✅ 88 passed |
| Backend e2e (real Postgres 16) | ✅ 24 passed, including concurrent confirmations and duplicate ID |
| Backend runtime (Docker, Node 24): migrations + seed + API | ✅ plus a 22-check HTTP smoke test |
| `flutter analyze` | ✅ no issues (strict casts / raw types) |
| `flutter test` | ✅ 41 passed (domain rules, error mapping, router guard, scan state machine, widgets) |
| Flutter ↔ live API contract test | ✅ login, token refresh, create, 409s, confirm, 404, list, stats, delete |
| `flutter build apk --release` | ✅ `app-release.apk` |
| Visual QA (web build of the same code, 390×844) | ✅ welcome, login + validation, list, details, scan: ready / confirmed / already taken / not found / camera unavailable, statistics, profile. It found and fixed 4 UI bugs (camera-less overlay, bidi text with Arabic names, close from a deep link, stray placeholder) |

## 6. What remains / manual steps

1. **Test on real phones with real QR cards** (camera focus, lighting, speed). The camera path
   could not be exercised here.
2. **Deploy the backend first** (`deploy-compose.sh`), then distribute the app. Confirm the
   production URL in `apps/mobile/config/production.json`: the Ionic app pointed to
   `vps-9e3159a8…`, while the new compose file defaults to `vps-ca2a6790…` (the latter is used).
3. **Release signing**: create a keystore and wire it into `android/app/build.gradle.kts`
   (currently signed with the debug key). Consider `--split-per-abi` (the universal APK is ~73 MB).
4. **iOS**: build and test on macOS (`pod install`/SPM, signing). No iOS app icon set was
   generated (the Ionic project had no iOS target).
5. **Rotate secrets**: JWT private keys and DB/admin passwords are committed in `setup.sh` and
   `apps/backend/.env*`. `src/cli.ts` also logs the admin password at startup.
6. **Region access control** is still not enforced: any logged-in user can read or modify
   another region by changing the URL. `GET /users` also lists all users to any volunteer.
7. Once validated during a distribution, delete `apps/legacy-ionic` and the Ionic-era
   `deploy.sh` / GitHub workflow.
