# Iftar Saim (إفطار صائم) — Pre-migration analysis

This analysis was written before any code changed. It covers the Ionic 7 / Angular 16 app
(originally at the repo root, now `apps/legacy-ionic/`) and the NestJS API (originally `api/`,
now `apps/backend/`).

## 1. What the product is

It is a volunteer tool for Ramadan iftar distribution. Each region (e.g. *Dar Sokra*, *Dar Sousse*)
keeps a list of registered **fasting people** (families and individuals). Each person holds a
pre-printed QR card that encodes their numeric **ID**. Every evening a volunteer scans the card and
sees how many **single** and **family** meals to hand over. Then the volunteer confirms the pickup,
so the same person can't collect twice on the same day. Region managers add and edit people and
check daily, weekly, or monthly statistics.

Users are volunteers working at a busy distribution point, often one-handed, often with a poor
network. Speed and "can this person take a meal right now?" are what matter most.

## 2. Main user flows

| # | Flow | Screens (Ionic) |
|---|------|-----------------|
| 1 | **Onboarding**: landing page (logo + Sign in / Sign up). A logged-in user is redirected to the list. | `home` |
| 2 | **Register**: name, username, region (from `GET /regions`), email, password. Then go to login. A 409 shows "Username or email is already in use". | `register` |
| 3 | **Login**: username + password → `POST /auth/login` → `GET /users/me`. The user and token are stored. | `login` |
| 4 | **Scan → validate → confirm** (core): FAB camera opens the native scanner (QR only). The scanned text is used as the person ID → `GET /fastings/:region/:id`. The screen shows ID, names, phone, meal counts, comment, and the "Meal taken" badge (`خذا` / `ما خذاش`). **"Confirm and scan another code"** confirms and reopens the scanner right away. If the meal is already taken, only "Scan another code" is shown. Phone and comment can be edited inline before confirming. Tapping the badge opens a bottom sheet with the history of meal dates. | `pages/scan` |
| 5 | **People list**: title "List of fasting people", search by name/ID (free-text across all fields), pull to refresh, tap → details. | `pages/list` |
| 6 | **Person details**: same info as the scan screen, "Confirm Meal", pull to refresh, Edit. | `pages/person/details/:code` |
| 7 | **Edit / delete person**: form + delete confirmation alert. | `pages/person/edit/:code` |
| 8 | **Add person**: ID (manual), CIN, names, phone, meals, comment, **"Came today"** (default on). | `pages/tab2` |
| 9 | **Statistics**: pick a period (Daily/Weekly/Monthly/Custom) with From/To dates → one card per day: served persons / total, family meals, single meals, total meals. "Choose another period" resets. | `pages/tab3` |
| 10 | **Profile**: name, username, region, email, "Export fasting persons list" (xlsx), logout. | `pages/tab-profile` |

Navigation: a bottom tab bar (list · add · **[center camera FAB in a notch]** · stats · profile).
The scan, details, and edit screens are pushed on top.

## 3. Business rules (explicit and implicit)

1. **One meal pickup per person per day.** "Today" is a *calendar day in local time* (Tunisia,
   UTC+1, no DST). The Ionic client compared `lastTakenMeal` with local midnight.
2. **Meal allotment**: `singleMeal` (count) and `familyMeal` (count). At least one must be > 0.
   If one is empty it becomes `0`. Error text: "Single meal or Family meal should be greater than 0".
3. **A family meal counts as 4 meals** in statistics (`totalMeals = single + family × 4`).
4. **Came today** on creation: if checked, today's meal is recorded as taken at creation.
   Otherwise `lastTakenMeal` is set to yesterday, so the person is eligible today.
5. **Region scoping**: every person belongs to the creating user's region. All calls use
   `currentUser.region.id`.
6. **Person IDs** are chosen by volunteers (the number printed on the card). They are globally
   unique (PK is `id` only) and integers.
7. **CIN** (national ID) is optional and exactly 8 characters.
8. **Required fields**: first name, last name, ID, meal counts. Password must be ≥ 6 characters on
   the backend (the Ionic UI checked ≥ 3 and said "8": inconsistent).
9. Phone and comment can be updated while confirming a meal.
10. Disabled accounts cannot log in.

## 4. Current architecture

**Mobile (Ionic 7 + Angular 16 + Capacitor 4/5):** NgModule pages lazy-loaded through the router.
There are two root services (`AuthenticationService`, `FastingPersonService`) plus
`RegionService`. HTTP interceptors add `Bearer` and log out on 401. State is kept in
`localStorage` (`user`, `token`). The scanner is the Cordova `phonegap-plugin-barcodescanner`,
which opens a full-screen native activity per scan. Export uses `xlsx` + Capacitor Filesystem.
No tests of substance.

**Backend (NestJS 10 + TypeORM 0.3 + PostgreSQL 16):** modules `auth` (local + JWT RS256
access/refresh), `user`, `region`, `fasting`, `health`. Response envelope is `{ data, meta }`.
Error envelope is `{ error: { statusCode, message, errorName, details, path, requestId, timestamp } }`.
Global prefix is `/api/v1`. The API is deployed as the Docker image `badredinebenfraj/iftar` behind
Caddy (TLS) using `docker-compose.yml` + `deploy-compose.sh`. Migrations and the CLI seed run at
container start.

## 5. Backend/API dependencies used by the app

| Method | Path | Used for |
|---|---|---|
| POST | `/auth/login` | `{username,password}` → `{data:{accessToken,refreshToken}}` |
| POST | `/auth/register` | `{name,username,email,password,region:{id}}` |
| POST | `/auth/refresh-token` | exists but **unused** by Ionic |
| GET | `/users/me` | profile + region |
| GET | `/regions` | registration picker (public) |
| GET | `/fastings/:region?limit&offset` | list (Ionic asked for limit 1000) |
| GET | `/fastings/:region/:id` | scan / details |
| POST | `/fastings` | create |
| PATCH | `/fastings/:region/:id` | edit |
| PATCH | `/fastings/confirm/:region/:id` | confirm meal |
| DELETE | `/fastings/:region/:id` | delete |
| GET | `/fastings/statistics/:region?start&end` | statistics |

## 6. Visual system

- Primary **teal `#43cebb`** (shade `#3bb5a5`, tint `#56d3c2`). Page background **`#f5f5f3`**.
  Tab bar `#f4f5f8`. Danger `#eb445a`.
- Logo: grey "رمضان كريم" calligraphy with a lantern (`assets/ramadan.png`). App name **إفطار صائم**.
- Auth screens: centered logo, **pill** inputs (radius 50, 45 px, soft shadow) and pill buttons
  (48 px, 18 px text).
- Content screens: Material list rows of *label : value*. Status pills are **green "خذا"** and
  **red "ما خذاش"**. Teal "bubbles" spinner.
- Bottom bar with a circular notch cut around a center camera FAB.
- Mixed language: English UI with Tunisian Arabic status words.

**Direction agreed during the migration:** keep the teal, the calligraphy, and the Arabic status
words, and add a *Ramadan night* feel: deep indigo night-sky hero, lantern-gold accents,
crescent/star motifs, warm ivory surfaces.

## 7. Defects found (these affect what "preserve behavior" means)

| Severity | Finding | Consequence |
|---|---|---|
| **Critical** | `PATCH /fastings/confirm` has **no server-side duplicate check**. It appends today's date to the *client-supplied* `takenMeals` array. | Two devices (or a double tap) can both confirm. The history can be overwritten by stale client data. The rule "prevent duplicate collection" was enforced only by the UI. |
| High | `POST /fastings` uses `save()` with a volunteer-chosen PK. | Adding a person whose ID already exists **silently overwrites** the existing person, even in another region. |
| High | Statistics `end` is parsed as midnight and compared with `<=`, and days are bucketed in server TZ (UTC). | The last day of the range is effectively excluded, so **"Daily" stats show 0**. Meals near midnight fall into the wrong day. |
| Medium | Region access is not checked: any logged-in user can read or modify any region by changing the URL. | Cross-region data exposure. Not fixed (flagged). |
| Medium | Ionic stored the JWT in `localStorage` and ignored refresh tokens. | Tokens are unprotected on the device. Volunteers are logged out when the token expires. |
| Medium | Export wrote the xlsx to the app's private data dir. | The user could never open the file. |
| Low | "Bulk mode" (add meals) submit is commented out. Password-reset and verify-email pages are stubs. `DELETE /:region/all` is called but doesn't exist. | Dead features. |
| Low | "Person not found" and "invalid QR" show the same message ("Invalid qr code"). | Volunteers can't tell a bad card from an unregistered person. |
| Security | `setup.sh` and `api/.env*` are committed with real-looking JWT private keys and DB passwords. | Rotate the secrets. Not changed here (it is deployment config). |

## 8. What could be lost or changed in migration

- **Scanner feel**: the Cordova scanner opened a new native screen per scan. A continuous in-app
  camera is faster but different. We keep the "confirm & scan next" one-tap rhythm.
- **Timezone semantics**: moving "already taken today" to the server needs an explicit timezone
  (`APP_TIMEZONE`, default `Africa/Tunis`).
- **Behavior change for the legacy app**: once the server rejects duplicate confirmations with 409,
  the Ionic app's second confirm fails (it silently resets). That is the intended fix.
- **Dropped dead features**: bulk mode, password reset, verify email.
- **Export**: same xlsx content, but now opened in the share sheet so it's actually usable.
- **Application ID**: a new ID lets both apps be installed side by side during migration.
- **iOS**: the Ionic project had no iOS platform. The Flutter project includes it, but it is
  unverified (it needs macOS).

## 9. Proposed Flutter architecture

- **Feature-first, layered**: `lib/features/<feature>/{domain,data,presentation}` plus `lib/core`
  (config, network, storage, theme, router, shared widgets).
  - *domain*: immutable models and pure business rules (QR parsing, meal-allotment validation,
    "taken today", period ranges). No Flutter imports, so it is unit-testable.
  - *data*: Dio API clients + repository implementations. Errors are mapped to a sealed
    `AppFailure` hierarchy (network / timeout / unauthorized / notFound / conflict /
    alreadyTaken / validation / server).
  - *presentation*: widgets + Riverpod `Notifier`s.
- **State/DI**: `flutter_riverpod`. Providers are the DI container and are overridable in tests.
- **Routing**: `go_router` with an auth-aware redirect and a `StatefulShellRoute` for the tabs.
- **Networking**: `dio` with an auth interceptor. It retries once via `/auth/refresh-token` and
  logs out if that fails.
- **Secure storage**: `flutter_secure_storage` (Keystore/Keychain) for tokens and the cached user.
- **Scanner**: `mobile_scanner` (CameraX/ML Kit on Android, AVFoundation on iOS). Continuous
  scanning, QR-only, duplicate-frame debounce, torch, manual ID entry fallback, haptics.
- **Config**: `--dart-define-from-file=config/<env>.json` (`API_BASE_URL`, `APP_ENV`).
- **Backend changes (minimal, necessary)**: atomic confirm with a row lock and a server-side
  "today" check (409 `MEAL_ALREADY_TAKEN`). The client-supplied `takenMeals` is ignored. Also a
  409 on duplicate person ID, inclusive, TZ-aware statistics, and a `mealTakenToday` flag in
  person responses. All changes stay compatible with the legacy Ionic app.
