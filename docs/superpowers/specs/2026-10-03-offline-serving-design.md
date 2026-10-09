# Spec 2B: Serving with no network (offline serve, sync, conflict review)

- **Date:** 2026-10-03 (split out of Spec 2, dated 2026-10-01)
- **Status:** Implemented (branch feat/offline-serving-2b, plan docs/superpowers/plans/2026-10-08-offline-serving-2b.md)
- **Scope:** `apps/backend` (NestJS + PostgreSQL) and `apps/mobile` (Flutter)
- **Depends on:** [Spec 2A](2026-10-01-serving-safety-backend-design.md), shipped and used in the January field dry run. 2B reuses its `meal_events` table, `clientEventId` / `deviceId`, dual-write, `PeopleCache`, connectivity detection, and the **Unverified** scan state.
- **Reference prototype:** [assets/2026-10-01-fusion-prototype.html](assets/2026-10-01-fusion-prototype.html). The offline and sync flows are already clickable there.

---

## 1. Intent

After 2A, a volunteer with no network can identify people but can't serve them. At a point with no coverage, that means either stopping the distribution or serving with no record at all. 2B lets the phone record the meal and sync it later.

**The trade-off this spec accepts:** two phones with no signal can both serve the same person. That can't be prevented without a connection. 2B makes it **visible, never silent**, and lets organizers decide per region whether to allow offline serving at all.

### Success criteria
1. **Where the region allows it,** a volunteer can serve with no network. Meals sync automatically when the network returns.
2. **No silent double serve.** Every case where two meals land on the same person and day is detected, stored, and shown to the volunteer and to admins.
3. Offline serving is **off by default** and enabled region by region.
4. No offline meal is lost on app restart, and logout can't drop unsynced meals by accident.

---

## 2. Scope

### In scope
- **Backend:** an offline sync endpoint, a region flag for offline serving, and an admin review endpoint.
- **App:**
  - "Serve offline" from the Unverified state.
  - Undo of a pending (unsynced) event.
  - A persisted sync queue.
  - Conflict and problem review.
  - A logout guard for unsynced meals.

### Out of scope
- An admin web dashboard for conflicts. Conflicts are visible via the API and in the app's banner.
- Peer-to-peer sync between phones (no network, no server).

---

## 3. Data model

- **No change to `meal_events`.** 2A already created `source = 'offline'`, `conflict`, and `flag`.
- **`regions.allowOfflineServing boolean NOT NULL DEFAULT false`.** Migration adds the column; down migration drops it.

---

## 4. API

All routes keep the existing JWT guard, region scoping, and the `{ data, meta }` envelope.

### 4.1 Offline sync (new): `POST /fastings/meals/sync`
**Request:**
```json
{ "events": [ { "clientEventId": "uuid", "fastingId": 142, "regionId": 3,
                "servedAt": "2027-02-21T17:44:10Z", "deviceId": "inst-…" } ] }
```
- Up to 200 events per request. The actor must belong to each event's region.

**Validation per event:**
- `servedAt` is no more than 5 min in the future and no more than 36 h in the past. Otherwise the result is `rejected: CLOCK_OUT_OF_RANGE`.
- The person exists in the region. Otherwise the result is `rejected: PERSON_NOT_FOUND`.
- If the region has `allowOfflineServing = false` at sync time, the event is **still applied**, because the meal already happened physically. It gets `flag = 'OFFLINE_NOT_ALLOWED'` for admin review, and the result is `applied` with that flag.

**Result per event, in the same order:**
| `status` | Meaning | App action |
|---|---|---|
| `applied` | Stored as the day's active event (`source = 'offline'`) and dual-written; may carry a `flag` | Drop from the queue |
| `duplicate` | `clientEventId` already stored | Drop from the queue |
| `conflict` | Person already had an active event that day. Stored with `conflict = true`; includes `{ other: { servedAt, servedBy } }` | Move to the conflicts list |
| `rejected` | Not stored; includes a `code` | Move to the problems list |

Each event is processed in its own transaction, so one bad event doesn't fail the batch.

### 4.2 Review (new): `GET /fastings/meals/review/:region?day=YYYY-MM-DD`
Returns the region's events that need admin attention: `conflict = true` or `flag IS NOT NULL`. It's admin-only.

### 4.3 Region flag (changed)
- Admins edit `allowOfflineServing` with the existing `PATCH /regions/:id`.
- It's included in the user profile's region object, so the app knows the policy.

---

## 5. App changes

### 5.1 Serve offline
The **Unverified** state (2A §5.6) gains a **Serve offline** action, shown only if the region's `allowOfflineServing` is true.

1. **The first time in a session,** a dialog appears: "Serve without checking?" It explains that this should only be done when no other volunteer is serving the region, that the meal syncs later, and that a double serve will be reported. The buttons are Serve offline and Cancel. Later offline serves in the same session skip the dialog.
2. **It creates a pending event:** `clientEventId`, the person, device-time `servedAt`, and `deviceId`. The event is persisted in the queue.
3. **The cached person is marked served locally.**
4. **The Confirmed state** says "Saved on this phone. Syncs when online." Undo is available.
5. **Undo of a pending event** removes it from the queue locally. No network is needed.

### 5.2 Sync queue
- **The queue is persisted** in the same encrypted store as `PeopleCache` and survives app restarts.
- **Flush triggers:** connectivity regained, app resumed, every 30 s while items are pending, and pull-to-refresh.
- **Results map to** §4.1.
- **The scan top bar** shows "{n} to sync". A toast reports "{n} offline meals synced".
- **After a flush,** the people list refreshes so the cache reflects the server.

### 5.3 Conflicts and problems
- They appear as a banner on People: "1 serving to review". It opens a sheet listing each item: the person, both times, who served, and the reason.
- The only action is **Acknowledge**. The server already stored it as flagged, and admins resolve it.

### 5.4 Logout guard
Logout with a non-empty queue is blocked with a dialog: "{n} meals haven't synced yet. Connect to sync before logging out." It offers "Log out anyway (meals will be lost)" as a destructive, explicitly confirmed option. The same guard applies to a region change, since 2A wipes the cache on region change.

---

## 6. Security and privacy
- The queue holds person IDs and timestamps only, in the encrypted store.
- Sync checks region membership per event on the server.
- `servedAt` comes from the device, so it's bounded (§4.1) and `receivedAt` is always server time.

---

## 7. Error handling
| Situation | Behavior |
|---|---|
| Sync partially fails | Per-event results. Failed items stay queued (network) or move to problems (rejected) |
| Device clock wrong | `rejected: CLOCK_OUT_OF_RANGE`. Shown in problems with "Check the phone's date and time" |
| Region disallows offline serving mid-session | The button disappears on the next profile refresh. Already-queued events still sync, applied with `flag = OFFLINE_NOT_ALLOWED` |
| Token expired while offline | Queue is kept. Sync waits for the refresh token; if that has expired too, the volunteer logs in again and the queue survives (same user only) |

---

## 8. Testing
- **Backend (Jest):**
  - Sync: `applied` / `duplicate` / `conflict` / `rejected` per event, and batch isolation.
  - Sync with `allowOfflineServing = false`: applied with `OFFLINE_NOT_ALLOWED`.
  - Clock bounds at exactly +5 min and −36 h.
  - Sync of an event whose ID was already confirmed online: `duplicate`.
  - Review endpoint: admin-only, returns conflicts and flagged events for the day.
- **App:**
  - The offline serve flow, the first-serve dialog, and Undo of a pending event.
  - Queue persistence across restart.
  - Each sync result path.
  - The conflict banner and sheet.
  - Logout and region change guarded by a non-empty queue.
- **Field test before enabling offline serving for a region:** two phones, airplane mode, and deliberate double serves, to confirm that conflicts surface on both phones and in the admin endpoint.

---

## 9. Rollout
1. **Backend release:** the region flag and the sync and review endpoints. Every region starts with offline serving off.
2. **App release:** Serve offline stays hidden until a region's flag is on.
3. **Enable `allowOfflineServing`** region by region, after the field test in §8.

---

## 10. Open questions
| Question | Proposal |
|---|---|
| Offline policy granularity | Per region (`allowOfflineServing`), default off |
| Retention of conflict events | Keep indefinitely (small rows, audit value) |
| Queue on a different user's login | Keep it but sync only as its original user; show "{n} meals from {name} waiting" |
| Maximum offline age | 36 h, matching the sync bound. Older items move to problems |
