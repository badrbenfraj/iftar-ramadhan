# Spec 2: Serving safety (Undo, served-by, offline serving)

- **Date:** 2026-10-01
- **Status:** Draft for review
- **Scope:** `apps/backend` (NestJS + PostgreSQL) and `apps/mobile` (Flutter)
- **Depends on:**
  1. [Spec 1, the app redesign](2026-10-01-fusion-app-redesign-design.md), which is merged first. This spec reuses its scan states, tokens, and l10n.
  2. The fix for the "fake meal yesterday" bug (`fasting.controller.ts` `createFasting`), in progress in a separate session. This spec assumes `fastings.lastTakenMeal` is nullable (migration `1790850000000-MakeLastTakenMealNullable`).
- **Reference prototype:** [assets/2026-10-01-fusion-prototype.html](assets/2026-10-01-fusion-prototype.html). The Undo, offline, and sync flows are already clickable there.

---

## 1. Intent

Three gaps the UX audit found that the app alone can't close:

| Gap | Today | Why it matters |
|---|---|---|
| **No undo** | A confirm permanently appends to `takenMeals`. There's no endpoint to reverse it | A mis-tap or wrong card blocks a person for the night |
| **No served-by** | Meals are stored as date strings only (`fasting.entity.ts:43`) | "Who gave him a meal?" can't be answered. Disputes can't be resolved |
| **Offline means stuck** | Every lookup and confirm needs the network | Distribution points often have poor coverage |

### Success criteria
1. A volunteer can undo their own confirm. The UI offers Undo for 5 s, and the server accepts it for up to 10 min.
2. "Already served" shows **when and by whom.**
3. With no network, a volunteer can still identify people from the phone and, **where the region allows it**, serve offline. Meals sync automatically when the network returns.
4. **No silent double serve.** Every case where two meals land on the same person and day is detected, stored, and shown to the volunteer and to admins.
5. **Backward compatible.** The legacy Ionic app and older Flutter builds keep working against the new backend.

---

## 2. Scope

### In scope
- **Backend:** a `meal_events` table, confirm idempotency, a revoke (undo) endpoint, an offline sync endpoint, served-by in responses, and a region flag for offline serving.
- **App:**
  - Undo.
  - Served-by display.
  - An encrypted on-device copy of the people list.
  - Offline identify and offline serve.
  - A persisted sync queue and conflict review.

### Out of scope
- Moving statistics to read from `meal_events`. Statistics stay on `fastings` thanks to dual-write (§3.3).
- An admin web dashboard for conflicts. Conflicts are visible via the API and in the app's banner.
- A server-side duplicate-CIN rule. That's its own small change; listed in §9.

---

## 3. Data model

### 3.1 New table `meal_events`
| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` PK | **Client-generated** (`clientEventId`) when the app sends one; otherwise server-generated |
| `fastingId` | `int` FK → `fastings.id` ON DELETE CASCADE | |
| `regionId` | `int` FK → `regions.id` | Denormalized for region-scoped queries |
| `servedAt` | `timestamptz` | Server time for online confirms; device time for offline serves |
| `serviceDay` | `date` | Local day of `servedAt` in `APP_TIMEZONE`, computed by the server |
| `receivedAt` | `timestamptz` default `now()` | |
| `servedByUserId` | `int` FK → `users.id`, nullable | Null only for backfilled history |
| `source` | `varchar` (`online` \| `offline` \| `backfill`) | |
| `deviceId` | `varchar(64)` nullable | Installation ID from the app |
| `conflict` | `boolean` default `false` | True when another active event already exists for the same person and `serviceDay` (a double serve) |
| `flag` | `varchar` nullable | Admin-review marker that doesn't change validity, e.g. `OFFLINE_NOT_ALLOWED` |
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

All routes keep the existing JWT guard, region scoping, ACL checks, and the `{ data, meta }` envelope.

### 4.1 Confirm (changed): `PATCH /fastings/confirm/:region/:id`
**Request body** adds optional `clientEventId` (uuid v4) and `deviceId`.

**Behavior:**
- **If an event with `clientEventId` already exists for this person:** return `200` with that event. This is idempotent and replaces the app's 3-minute "own confirmation" heuristic; keep the heuristic for old clients.
- **Else, if an active event exists for `serviceDay(now)`:** return `409 MEAL_ALREADY_TAKEN` with `{ servedAt, servedBy: { id, name } | null }`.
- **Else:** insert the event (`source = 'online'`), dual-write, and return `200`.

**Response:** the person (as today) plus `meal: { eventId, servedAt, servedBy: { id, name } }`.

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

### 4.3 Offline sync (new): `POST /fastings/meals/sync`
**Request:**
```json
{ "events": [ { "clientEventId": "uuid", "fastingId": 142, "regionId": 3,
                "servedAt": "2027-02-21T17:44:10Z", "deviceId": "inst-…" } ] }
```
- Up to 200 events per request. The actor must belong to each event's region (existing ACL).

**Validation per event:**
- `servedAt` is no more than 5 min in the future and no more than 36 h in the past. Otherwise the result is `rejected: CLOCK_OUT_OF_RANGE`.
- The person exists in the region. Otherwise the result is `rejected: PERSON_NOT_FOUND`.
- If the region has `allowOfflineServing = false` at sync time, the event is **still applied**, because the meal already happened physically. It gets `flag = 'OFFLINE_NOT_ALLOWED'` for admin review, and the result is `applied` with that flag.

**Result per event, in the same order:**
| `status` | Meaning | App action |
|---|---|---|
| `applied` | Stored as the day's active event and dual-written; may carry a `flag` | Drop from the queue |
| `duplicate` | `clientEventId` already stored | Drop from the queue |
| `conflict` | Person already had an active event that day. Stored with `conflict = true`; includes `{ other: { servedAt, servedBy } }` | Move to the conflicts list |
| `rejected` | Not stored; includes a `code` | Move to the problems list |

Each event is processed in its own transaction, so one bad event doesn't fail the batch.

### 4.4 Reads (changed)
- `GET /fastings/:region` and `GET /fastings/:region/:id` add `todayMeal: { eventId, servedAt, servedBy: { id, name } } | null`.
- A new `GET /fastings/meals/review/:region?day=YYYY-MM-DD` returns the region's events that need admin attention: `conflict = true` or `flag IS NOT NULL`. It's admin-only.

### 4.5 Region flag (changed)
- `regions.allowOfflineServing boolean NOT NULL DEFAULT false`. Admins edit it with the existing `PATCH /regions/:id`.
- It's included in the user profile's region object, so the app knows the policy.

---

## 5. App changes

### 5.1 Undo
- **The confirm request sends a fresh `clientEventId`.** Retries reuse the same ID, so they're idempotent.
- **The Confirmed state** (Spec 1 §4.6) gains an **Undo · 5** button with a countdown. It replaces the 1.6 s auto-resume with:
  - The camera is live immediately.
  - The band stays for 5 s.
  - Scanning the next card dismisses it.
- **Tapping Undo calls `revoke`:**
  - The button shows a spinner.
  - On success, the toast says "Undone. {name} is not marked as served."
  - On failure, the toast says "Couldn't undo. Try again from History."
- **The History sheet** shows "Undo tonight's meal" on the volunteer's own event while the server window is open.
- **For an offline serve,** Undo removes the pending event locally. No network is needed.

### 5.2 Served-by
- The Already-taken panel shows "Served at 18:12 by Sami." When `servedBy` is null (backfill), it shows the time only.
- Meal history rows show the volunteer's name when known.

### 5.3 On-device people list
- **`PeopleCache`** stores the region's list plus `lastSyncedAt`:
  - JSON encrypted with AES-GCM.
  - The key is held in `flutter_secure_storage`.
  - The file lives in the app documents directory.
- **When it updates:** on every successful list load, after each sync, and after confirms.
- **When it's wiped:** on logout and on a region change.
- **On startup,** the cached list shows immediately with a "Last updated 18:05" line, while the network refresh runs.
- **New dependency:** one audited crypto package, `cryptography`. It's chosen in the plan and needs approval.

### 5.4 Connectivity
- **"Offline" is detected from request outcomes** (`NetworkFailure` / `TimeoutFailure`), plus a 15 s `GET /health` probe while offline.
- **No new connectivity plugin is required.**
- **People list banner:** "Offline · using the list saved at {time}".
- **Scan screen:** a gold offline icon in the top bar.

### 5.5 Offline identify and serve
New scan states (styled per Spec 1 §4.6):

| State | Shown when | Content | Actions |
|---|---|---|---|
| **Unverified** | Lookup fails offline and the person is cached and not served in the cache | `system` band: "Can't check tonight", plus "Last sync {time}: not served yet". Name, tiles | Retry; **Serve offline** (only if `allowOfflineServing`); Skip |
| Already taken (cached) | Offline, and the cache says served today | As Spec 1, plus "(as of {time})" | Scan next |
| Not on this phone | Offline, and the ID isn't cached | `system` band: "Card #{id} isn't on this phone" | Scan again |

**"Serve offline" flow:**
1. **The first time in a session,** a dialog appears: "Serve without checking?" It explains that this should only be done when no other volunteer is serving the region, that the meal syncs later, and that a double serve will be reported. The buttons are Serve offline and Cancel. Later offline serves in the same session skip the dialog.
2. **It creates a pending event:** `clientEventId`, the person, device-time `servedAt`, and `deviceId`. The event is persisted in the queue.
3. **The cached person is marked served locally.**
4. **The Confirmed state** says "Saved on this phone. Syncs when online." Undo is available.

### 5.6 Sync queue
- **The queue is persisted** in the same encrypted store and survives app restarts.
- **Flush triggers:** connectivity regained, app resumed, every 30 s while items are pending, and pull-to-refresh.
- **Results map to** §4.3.
- **The scan top bar** shows "{n} to sync". A toast reports "{n} offline meals synced".
- **Conflicts and problems** appear as a banner on People: "1 serving to review". It opens a sheet listing each item: the person, both times, who served, and the reason. The only action is **Acknowledge**. The server already stored it as flagged, and admins resolve it.
- **Logout with a non-empty queue** is blocked with a dialog: "{n} meals haven't synced yet. Connect to sync before logging out." It offers "Log out anyway (meals will be lost)" as a destructive, explicitly confirmed option.

---

## 6. Security and privacy
- The on-device list contains PII (names, CIN, phone). It's **encrypted at rest**, wiped on logout, and scoped to one region.
- The CIN stays masked in the scan and find screens (Spec 1). The full CIN appears only in details and edit.
- Events form an audit trail. Revoked events are kept, not deleted.
- No PII in logs. Backend logs use IDs only.
- Revoke permissions are enforced on the server. The UI only hides what isn't allowed.

---

## 7. Error handling
| Situation | Behavior |
|---|---|
| Revoke after the window | `403 UNDO_WINDOW_EXPIRED`. App: "It's too late to undo. Ask an admin." |
| Revoke while offline (online event) | Not possible, because it needs the server. App: "Undo needs a connection. Try again from History." |
| Sync partially fails | Per-event results. Failed items stay queued (network) or move to problems (rejected) |
| Device clock wrong | `rejected: CLOCK_OUT_OF_RANGE`. Shown in problems with "Check the phone's date and time" |
| Region disallows offline serving mid-session | The button disappears on the next profile refresh. Already-queued events still sync, applied with `flag = OFFLINE_NOT_ALLOWED` |

---

## 8. Testing
- **Backend (Jest):**
  - Confirm idempotency (same `clientEventId` twice), 409 with servedBy, and the dual-write consistency of `takenMeals`/`lastTakenMeal`.
  - Revoke: own within the window, own after the window, someone else's, admin same day, idempotent revoke, and dual-write removal.
  - Sync: `applied` / `duplicate` / `conflict` / `rejected` per event, and batch isolation.
  - `serviceDay` at `APP_TIMEZONE` day boundaries (23:59 vs 00:01 local).
  - The partial unique index blocks a second active event.
  - Migration backfill counts match `takenMeals` lengths. The down migration leaves `fastings` intact.
- **App:**
  - The offline state machine (Unverified, serve offline, Undo of a pending event).
  - Queue persistence across restart.
  - Each sync result path.
  - The conflict banner and sheet.
  - Logout guarded by a non-empty queue.
  - Encrypted cache round-trip and wipe on logout.
- **Field test before enabling offline serving for a region:** two phones, airplane mode, and deliberate double serves, to confirm that conflicts surface on both phones and in the admin endpoint.

---

## 9. Rollout
1. **Backend release:** the migration, the new endpoints, and the dual-write. Old clients are unaffected.
2. **App release:** Undo and served-by are on for everyone. Offline serving stays dormant until a region's flag is enabled.
3. **Enable `allowOfflineServing`** region by region, after the field test in §8.
4. **Follow-ups, not in this spec:**
  - A server-side duplicate-CIN rule.
  - Statistics read from `meal_events` (excluding revoked and flagged events).
  - Optional cleanup of historical fake "yesterday" meals created by the old registration bug, which needs admin review.

---

## 10. Open questions
| Question | Proposal |
|---|---|
| UI undo window vs server window | 5 s in the UI, 10 min on the server (`UNDO_WINDOW_MINUTES`) |
| Who can revoke later the same day? | Admins only |
| Offline policy granularity | Per region (`allowOfflineServing`), default off |
| Retention of revoked/conflict events | Keep indefinitely (small rows, audit value) |
| Crypto package for the cache | `cryptography`, to be confirmed in the plan |
