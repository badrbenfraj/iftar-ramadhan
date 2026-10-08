# Spec 2A: Serving safety on a bad connection (Undo, served-by, offline identify)

- **Date:** 2026-10-01 (split into 2A / 2B on 2026-10-03)
- **Status:** Implemented (branch feat/serving-safety-2a, plan docs/superpowers/plans/2026-10-07-serving-safety-2a.md)
- **Scope:** `apps/backend` (NestJS + PostgreSQL) and `apps/mobile` (Flutter)
- **Depends on:**
  1. [Spec 1, the app redesign](2026-10-01-fusion-app-redesign-design.md), merged. This spec reuses its scan states, tokens, and l10n.
  2. The fix for the "fake meal yesterday" bug, merged. `fastings.lastTakenMeal` is nullable (`fasting.entity.ts:40`).
- **Followed by:** [Spec 2B, serving with no network](2026-10-03-offline-serving-design.md). 2B builds on the table, IDs, and on-device list defined here and adds no new table.
- **Reference prototype:** [assets/2026-10-01-fusion-prototype.html](assets/2026-10-01-fusion-prototype.html). The Undo and offline flows are already clickable there.

---

## 0. Why two phases

A slow or flaky connection is far more common at a distribution point than no connection at all, and it can be fixed **without any risk of serving one person twice**. Serving with no network can't: two phones with no signal can both serve the same person, and the system can only detect that afterwards.

| | 2A (this spec) | 2B |
|---|---|---|
| Goal | Never lose or double a meal because of a bad connection. Identify people with no network | Serve with no network, sync later |
| Double-serve risk | None. The server still decides every serve | Accepted, detected, and reported |
| Ships | Before the January field dry run | After the dry run, enabled region by region |

---

## 1. Intent

Gaps the UX audit found that the app alone can't close:

| Gap | Today | Why it matters |
|---|---|---|
| **Retries guess** | The app treats a 409 within 3 minutes of its own confirm as "probably ours" (`scan_controller.dart:159`) | On a slow connection a confirm can arrive late or twice. A guess can hide a real second serve, or flag a person wrongly |
| **No undo** | A confirm permanently appends to `takenMeals`. There's no endpoint to reverse it | A mis-tap or wrong card blocks a person for the night |
| **No served-by** | Meals are stored as date strings only (`fasting.entity.ts:43`) | "Who gave him a meal?" can't be answered. Disputes can't be resolved |
| **Offline means blind** | The people list is kept in memory only. After a restart with no network, nobody can be identified | Volunteers can't even tell people whether they've been served |
| **Slow means frozen** | A confirm waits up to 20 s with no feedback | Volunteers tap again, or give up and hand over the meal anyway |

### Success criteria
1. **A confirm is idempotent.** Retrying it on a bad connection never creates a second meal and never shows a wrong "already served".
2. A volunteer can undo their own confirm. The UI offers Undo for 5 s, and the server accepts it for up to 10 min.
3. "Already served" shows **when and by whom.**
4. With no network, a volunteer can still **identify** people from the phone and see whether they were served as of the last sync. Serving still needs the server.
5. A slow confirm shows clear progress within 2 s and never ends in an ambiguous state.
6. **Backward compatible.** The legacy Ionic app and older Flutter builds keep working against the new backend.

---

## 2. Scope

### In scope
- **Backend:** a `meal_events` table with backfill and dual-write, confirm idempotency, a revoke (undo) endpoint, and served-by in responses.
- **App:**
  - Idempotent confirm with a client-generated ID.
  - Clear progress and retry on a slow confirm.
  - Undo.
  - Served-by display.
  - An encrypted on-device copy of the people list.
  - Offline identify (read-only).

### Out of scope (moved to [Spec 2B](2026-10-03-offline-serving-design.md))
- Serving with no network, the sync queue, and the sync endpoint.
- The `allowOfflineServing` region flag.
- Conflict review (endpoint, banner, sheet).

### Out of scope (both phases)
- Moving statistics to read from `meal_events`. Statistics stay on `fastings` thanks to dual-write (§3.3).
- An admin web dashboard.
- A server-side duplicate-CIN rule. That's its own small change; listed in §9.

---

## 3. Data model

### 3.1 New table `meal_events`
The table is created with **every column 2B needs**, so 2B needs no change to it. In 2A, `source` is only ever `online` or `backfill`, and `conflict` is only set by the backfill.

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | **Client-generated** (`clientEventId`) when the app sends one; otherwise server-generated |
| `fastingId` | `int` FK → `fastings.id` ON DELETE CASCADE | |
| `regionId` | `int` FK → `regions.id` | Denormalized for region-scoped queries |
| `servedAt` | `timestamptz` | Server time for online confirms (device time for offline serves in 2B) |
| `serviceDay` | `date` | Local day of `servedAt` in `APP_TIMEZONE`, computed by the server |
| `receivedAt` | `timestamptz` default `now()` | |
| `servedByUserId` | `int` FK → `users.id`, nullable | Null only for backfilled history |
| `source` | `varchar` (`online` \| `offline` \| `backfill`) | `offline` is used from 2B on |
| `deviceId` | `varchar(64)` nullable | Installation ID from the app |
| `conflict` | `boolean` default `false` | True when another active event already exists for the same person and `serviceDay` (a double serve) |
| `flag` | `varchar` nullable | Admin-review marker that doesn't change validity. Unused in 2A |
| `revokedAt` | `timestamptz` nullable | |
| `revokedByUserId` | `int` FK → `users.id`, nullable | |

Indexes:
- `UNIQUE (fastingId, serviceDay) WHERE revokedAt IS NULL AND conflict = false`. This is **the database-level guarantee of one meal per person per day.**
- `(regionId, serviceDay)` and `(fastingId, servedAt DESC)`.

### 3.2 Migration
1. Create the table and indexes.
2. **Backfill** one event per entry in `fastings.takenMeals`:
   - `source = 'backfill'`, `servedByUserId = null`.
   - `serviceDay` is computed with `APP_TIMEZONE`.
   - Duplicates on the same day become `conflict = true`.
3. **Down migration:** drop the table. `fastings` is untouched, so this is lossless for old clients.

### 3.3 Dual-write (compatibility)
- **An event is *active*** when `revokedAt IS NULL AND conflict = false`. At most one active event exists per person per day (index above).
- **Conflict events are never dual-written.** They're records of a second physical serve. The person already counts as served that day through the active event.
- **Every insert or revoke of an active event** also updates `fastings.takenMeals` and `fastings.lastTakenMeal` **in the same transaction**:
  - Insert: append the ISO string and set `lastTakenMeal`.
  - Revoke: remove that ISO string, and set `lastTakenMeal` to the latest remaining active event, or null.
- So the existing statistics query, the legacy Ionic app, and older Flutter builds see consistent data.
- The existing `SELECT … FOR UPDATE` on the `fastings` row stays the serialization point for a person.

---

## 4. API

All routes keep the existing JWT guard, region scoping, and the `{ data, meta }` envelope.

### 4.1 Confirm (changed): `PATCH /fastings/confirm/:region/:id`
**Request body** adds optional `clientEventId` (uuid v4) and `deviceId`.

**Behavior:**
- **If an event with `clientEventId` already exists for this person:** return `200` with that event, even if it has since been revoked (the response then shows `revokedAt`). This is idempotent and replaces the app's 3-minute "own confirmation" heuristic; keep the heuristic for old clients that send no ID.
- **If `clientEventId` exists for a different person:** `422 CLIENT_EVENT_ID_REUSED`.
- **Else, if an active event exists for `serviceDay(now)`:** return `409 MEAL_ALREADY_TAKEN` with `{ servedAt, servedBy: { id, name } | null }`.
- **Else:** insert the event (`source = 'online'`), dual-write, and return `200`.

**Response:** the person (as today) plus `meal: { eventId, servedAt, servedBy: { id, name }, revokedAt }`.

### 4.2 Undo (new): `POST /fastings/meals/:eventId/revoke`
**Allowed when either:**
- the actor is the event's `servedByUserId`, **and** `now − receivedAt ≤ UNDO_WINDOW_MINUTES` (env, default `10`); or
- the actor has role `ADMIN`, and the event's `serviceDay` is today.

**Behavior:**
- Sets `revokedAt` and `revokedByUserId`, dual-writes the removal, and returns the updated person.
- **Idempotent:** revoking an already-revoked event returns `200` with the current state.

**Errors:**
- `404 MEAL_EVENT_NOT_FOUND`.
- `403 UNDO_NOT_ALLOWED`, for someone else's event when the actor isn't an admin.
- `403 UNDO_WINDOW_EXPIRED`.

### 4.3 Reads (changed)
- `GET /fastings/:region` and `GET /fastings/:region/:id` add `todayMeal: { eventId, servedAt, servedBy: { id, name } | null } | null`.
- Meal history (in `GET /fastings/:region/:id`) adds `meals: [{ eventId, servedAt, servedBy, revokedAt }]` next to the existing `takenMeals`, which is unchanged for old clients.

---

## 5. App changes

### 5.1 Idempotent confirm and slow-network feedback
- **Each confirm gets a fresh `clientEventId`** (uuid v4) when the volunteer taps Confirm. Every retry of that confirm reuses it. `deviceId` is an installation ID generated once and kept in secure storage.
- **The 3-minute own-confirmation heuristic is removed** for this app version: the server now answers a retry with the original event.
- **Progress:**
  - 0–2 s: the Confirm button shows a spinner (as today).
  - After 2 s: the band says "Sending… slow connection". The camera stays paused and the confirm can't be tapped twice.
  - On timeout or a network error: the band says "Not confirmed yet. Don't hand over the meal." with **Retry** (same `clientEventId`) and **Cancel**.
  - Retry is automatic once after 3 s, then manual.
- **The Confirmed state is shown only after the server's `200`.** There is no state where the volunteer can't tell whether the meal counted.
- **Timeouts** in `api_client.dart`: `connectTimeout` stays 10 s; `receiveTimeout` and `sendTimeout` go from 20 s to 15 s for confirm and revoke, since the retry is now safe.

### 5.2 Undo
- **The Confirmed state** (Spec 1 §4.6) gains an **Undo · 5** button with a countdown. It replaces the 1.6 s auto-resume with:
  - The camera is live immediately.
  - The band stays for 5 s.
  - Scanning the next card dismisses it.
- **Tapping Undo calls `revoke`:**
  - The button shows a spinner.
  - On success, the toast says "Undone. {name} is not marked as served."
  - On failure, the toast says "Couldn't undo. Try again from History."
- **The History sheet** shows "Undo tonight's meal" on the volunteer's own event while the server window is open.

### 5.3 Served-by
- The Already-taken panel shows "Served at 18:12 by Sami." When `servedBy` is null (backfill), it shows the time only.
- Meal history rows show the volunteer's name when known.

### 5.4 On-device people list
- **`PeopleCache`** stores the region's list plus `lastSyncedAt`:
  - JSON encrypted with AES-GCM.
  - The key is held in `flutter_secure_storage` (already a dependency).
  - The file lives in the app documents directory (`path_provider`, already a dependency).
- **When it updates:** on every successful list load and after each confirm or undo.
- **When it's wiped:** on logout and on a region change.
- **On startup,** the cached list shows immediately with a "Last updated 18:05" line, while the network refresh runs. On a slow connection this also makes People usable before the refresh finishes.
- **New dependency:** one audited crypto package, `cryptography`. It's chosen in the plan and needs approval.

### 5.5 Connectivity
- **"Offline" is detected from request outcomes** (`NetworkFailure` / `TimeoutFailure`), plus a 15 s `GET /health` probe while offline.
- **No new connectivity plugin is required.**
- **People list banner:** "Offline · using the list saved at {time}".
- **Scan screen:** a gold offline icon in the top bar.

### 5.6 Offline identify (read-only)
New scan states (styled per Spec 1 §4.6). **None of them can serve.** 2B adds "Serve offline" to the first one.

| State | Shown when | Content | Actions |
|---|---|---|---|
| **Unverified** | Lookup fails offline, and the person is cached and not served in the cache | `system` band: "Can't check tonight", plus "Last sync {time}: not served yet". Name, tiles | Retry; Skip |
| Already taken (cached) | Offline, and the cache says served today | As Spec 1, plus "(as of {time})" | Scan next |
| Not on this phone | Offline, and the ID isn't cached | `system` band: "Card #{id} isn't on this phone" | Scan again |

Find-without-card (Spec 1) searches the on-device list when offline, with the same "(as of {time})" note.

---

## 6. Security and privacy
- The on-device list contains PII (names, CIN, phone). It's **encrypted at rest**, wiped on logout, and scoped to one region.
- The CIN stays masked in the scan and find screens (Spec 1). The full CIN appears only in details and edit.
- Events form an audit trail. Revoked events are kept, not deleted.
- No PII in logs. Backend logs use IDs only.
- Revoke permissions are enforced on the server. The UI only hides what isn't allowed.
- **Precondition:** region access control (`MIGRATION_REPORT.md` §6.6) should be enforced before this ships, since the new endpoints take region and event IDs from the client.

---

## 7. Error handling
| Situation | Behavior |
|---|---|
| Confirm times out | "Not confirmed yet. Don't hand over the meal." Retry reuses the `clientEventId`, so it can't double |
| Retry lands after the first request succeeded | Server returns the original event (`200`). App shows Confirmed |
| Revoke after the window | `403 UNDO_WINDOW_EXPIRED`. App: "It's too late to undo. Ask an admin." |
| Revoke while offline | Not possible, because it needs the server. App: "Undo needs a connection. Try again from History." |
| Cache can't be decrypted (key lost, OS restore) | Delete the file silently and load from the network |

---

## 8. Testing
- **Backend (Jest):**
  - Confirm idempotency (same `clientEventId` twice, including after a revoke), `CLIENT_EVENT_ID_REUSED`, 409 with servedBy, and the dual-write consistency of `takenMeals`/`lastTakenMeal`.
  - Two concurrent confirms with different IDs for the same person: exactly one `200`, one `409`.
  - Revoke: own within the window, own after the window, someone else's, admin same day, idempotent revoke, and dual-write removal.
  - `serviceDay` at `APP_TIMEZONE` day boundaries (23:59 vs 00:01 local).
  - The partial unique index blocks a second active event.
  - Migration backfill counts match `takenMeals` lengths. The down migration leaves `fastings` intact.
  - Old-client confirm (no `clientEventId`) behaves as today.
- **App:**
  - Confirm progress states: fast, slow (>2 s), timeout, automatic retry, manual retry, cancel.
  - A retry reuses the same `clientEventId`; a new tap creates a new one.
  - Undo within 5 s, Undo failure, Undo from History.
  - The offline identify states and the find-without-card offline path.
  - Encrypted cache round-trip, wipe on logout and region change, and recovery from an undecryptable file.
- **Field check (dry run):** throttle a phone to 2G/EDGE and confirm 20 people in a row; then airplane mode and identify 10 people after an app restart.

---

## 9. Rollout
1. **Backend release:** the migration, the changed confirm, revoke, and reads. Old clients are unaffected.
2. **App release:** idempotent confirm, Undo, served-by, the on-device list, and offline identify, for everyone.
3. **Field dry run** in January.
4. **Then [Spec 2B](2026-10-03-offline-serving-design.md).**
5. **Follow-ups, not in either spec:**
   - A server-side duplicate-CIN rule.
   - Statistics read from `meal_events` (excluding revoked and flagged events).
   - Optional cleanup of historical fake "yesterday" meals created by the old registration bug, which needs admin review.

---

## 10. Open questions
| Question | Proposal |
|---|---|
| UI undo window vs server window | 5 s in the UI, 10 min on the server (`UNDO_WINDOW_MINUTES`) |
| Who can revoke later the same day? | Admins only |
| Retention of revoked events | Keep indefinitely (small rows, audit value) |
| Crypto package for the cache | `cryptography`, to be confirmed in the plan |
| Slow-confirm thresholds | 2 s to show "Sending…", one automatic retry after 3 s. Tune after the dry run |
