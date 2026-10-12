# Cards per region, code-only sign-up, card sheet: design

Date: 2026-10-12 · Branch: `feat/regions-and-cards` (built on `feat/admin-add-region`)

## Context and goals

- Every region prints the same card numbers, so card #1 exists in several regions. Each region prints its own batch once before Ramadan, and the size of the batch differs (for example 500 in one region and 100 in another). A person's card number never changes.
- **Bug:** the API treats the card number as a global key. The primary key of `fastings` is `(id)`, the create check is global (`PERSON_ID_TAKEN`), and the one-meal index is on `(fastingId, serviceDay)`. The second region to register card #1 gets a 409.
- **Exposure:** `GET /api/v1/regions` has no login check. It lists every open distribution point to anyone. Only the sign-up picker uses it.
- **Card tool:** `packages/qrcode-gen` (Puppeteer, never committed) breaks on Windows because `new URL().pathname` resolves to `C:\C:\…`. It always prints cards 1–1500 and needs Node plus a Chromium download for a once-a-year job.

Goals: (1) people are keyed by region plus card number; (2) the only way into a region is its join code, with optional approval per region; (3) a static card sheet page that needs no installation.

Non-goals: see "Parked".

## Part 1: People keyed by region and card number

**Database (one migration)**
- `fastings`: change the primary key from `(id)` to `("regionId", "id")`. `id` keeps its meaning (the card number), so API field names and the app model are unchanged.
- `meal_events`:
  - Replace `FK_meal_events_fasting` with `("regionId","fastingId") → fastings("regionId","id") ON DELETE CASCADE`.
  - `UQ_meal_events_active_day` becomes `("regionId","fastingId","serviceDay") WHERE "revokedAt" IS NULL AND "conflict" = false`.
  - `IDX_meal_events_fasting_served` becomes `("regionId","fastingId","servedAt")`.
- `deploy/local/seed.sql`: two regions get overlapping card numbers.
- Production is not live, so no data needs moving beyond the key change.
- The `regions (id, name)` primary key is left as it is.

**Backend:** every lookup by card number also takes the region.
- `FastingService.createFasting`: the "ID taken" check runs per region.
- `MealEventService`: the lookup by `id` alone (around line 139), `todayMealOf`, and history queries.
- Statistics and review queries join on `(regionId, fastingId)`.
- The `fastings` entity: a composite primary key, and the relation from `meal_events` uses both columns.

**Removed:** changing a person's region through `PATCH /fastings/:region/:id` (`input.region`). The app never offered it. To move someone, register them at the new point with one of that point's cards. A meal's region is then always its person's region, so past statistics never shift. The `region` field is dropped from the update input.

**App:** in the global admin's "every region" people view, two people can now share a number.
- List keys and the person-details route carry the region.
- `personRegion(ref, personId)` no longer guesses the region from the number.
- Scanning, the on-phone copy and the offline queue are already per region and don't change.

**Manual check on the local stack** (in place of tests):
- Card 42 is served at region A and at region B on the same night: both succeed.
- A second serve of 42 at region A: `409 MEAL_ALREADY_TAKEN`.
- An offline sync of a duplicate at region A is marked as a conflict.
- Registering 42 twice in region A gives `PERSON_ID_TAKEN`; registering it in region B succeeds.

## Part 2: Sign-up by join code only

**Backend**
- Remove `GET /regions`, the public list. The admin screens use `GET /regions/all`.
- `RegisterInput`: `joinCode` is required and `region` is removed. The code alone selects the active region.
  - An unknown code, a code that was turned off, and a closed region's code all return the same `INVALID_JOIN_CODE` ("This join code is not valid").
  - The existing limit of 5 attempts per 10 minutes stays.
- New column `regions."approveNewVolunteers" boolean NOT NULL DEFAULT true`.
  - On: sign-up creates a `PENDING` account, and the existing approve and refuse flow applies.
  - Off: sign-up creates an `ACTIVE` account.
  - It can be read and changed by the region's coordinator and global admins, through the same check as the join code (`regionForAdmin`). `GET /regions/:id/join-code` returns `{ joinCode, approveNewVolunteers }`. A new endpoint, `PUT /regions/:id/approval` with the body `{ approveNewVolunteers: boolean }`, changes it.
- Remove the `users."joinedWithCode"` column, its DTO fields and the "Joined with code" tag. Everyone joins with a code now. `approvedByUserId` already records who approved someone.
- Existing accounts, including those waiting, are untouched.
- A region whose code is turned off accepts no sign-ups.

**App**
- Sign-up screen:
  - Remove the region picker and its `regionsProvider` and retry states, and `listRegions()` in `auth_repository.dart`.
  - The code field is required. New help text: "Ask your coordinator for your region's code."
- Waiting page: names the region ("A coordinator of {region} must approve it"), using the region returned by sign-up.
- Join-code card (Volunteers screen): adds an **"Approve new volunteers"** switch. The text under it reads: "On: people who sign up with the code wait for your approval. Off: they start at once."
- Volunteers list: remove the "Joined with code" tag.
- Every text change in EN/FR/AR goes through the translation files (`add-translation`). `RegionPicker` stays, because the admin screens use it.

## Part 3: Ready-to-print cards

**What organizers get:** one PDF, `iftar-cards-1-2000.pdf` (cards 1–2000, 25 per A4 page, 80 pages), linked on the `/download` page next to the APK. Page *p* holds cards `25·(p−1)+1` to `25·p`. The download page shows "100 cards → print pages 1–4, 500 cards → pages 1–20", and says to print the next pages when more cards are needed. No tool and no settings: open the PDF and print the pages you need.

- The PDF is committed at `apps/backend/assets/cards/iftar-cards-1-2000.pdf` and served by the API at `GET /download/cards.pdf` (public, like the APK download). It goes into the backend Docker image.
- `download-page.ts` gains a "Cards to print" section with the link and the page table, in the page's existing languages.

**How the PDF is made (maintainer only, rarely):** the static page below. It is committed so the PDF can be regenerated, for example for cards 2001–4000.

**Files:** `packages/card-sheet/index.html`, plus a vendored `packages/card-sheet/qrcode.js` (`qrcode-generator` 1.4.4, Kazuhiko Arase, MIT) with its license file. `packages/qrcode-gen` is deleted. It was never committed.

**Use**
1. Double-click `index.html` and it opens in Chrome, Edge or Firefox from `file://`. There is no build step and there are no ES modules.
2. Enter **From** and **To** (for example 1–500). The page shows "N cards · P pages" and a live preview.
3. Click **Print / Save as PDF** (`window.print()`). Instructions next to the button: Save as PDF, A4, scale 100%. The form is hidden when printing.

There is no region field. One generic sheet works for every region, because the app already knows the volunteer's region.

**Each card**
- The QR code holds the plain number (`42`), which is what `QrPayload.parse` accepts today. It uses error-correction level H; a short number still fits the smallest QR version (21×21), so the squares stay large. It is drawn as SVG, about 30 mm wide.
- The number is printed large under the QR, for typing by hand when a QR is damaged.
- It uses system fonts.

**Sheet:** `@page { size: A4; margin: 0 }`, so no browser header or footer prints. The sheet has 8 mm of padding and a 5 × 5 grid of cards (about 39 × 56 mm) with light dashed cut lines.

**Validation:** From ≥ 1, To ≥ From, To ≤ 2147483647, and at most 2,000 cards per run.

**Docs:** in `packages/README.md`, how to regenerate the PDF. In the README's "Use it for your organization" steps, "print cards from the /download page".

## Parked (not in this work)

The following were designed on 2026-10-12, then parked as speculative because nobody has asked for them. Revisit after Ramadan 2027 if coordinators ask.
- **Multi-region volunteers:**
  - one account, with one membership per region (its own role and its own waiting or active status)
  - join with a code or by request
  - a "Where are you serving tonight?" check-in for members of 2+ regions
  - coordinators can only "remove from region"; disabling an account becomes global-admin only
  - "last served here" per member
  - region closure ends memberships, replacing `previousRegionId`

  Workarounds until then: a global admin moves the user, makes a multi-point organizer a global admin, or the person uses a second account.
- **Region-tagged QR** (`IFTAR:<regionId>:<n>`): detects a card from another region. It is only worth building alongside multi-region volunteers.
- **Cross-region CIN warning:** the same person registered in two regions.

## Delivery

- Order: Part 1 → Part 2 → Part 3. Parts 2 and 3 are independent.
- Verify with `npm run build`, `npm run lint` and `flutter analyze` (no tests, by the owner's preference), plus the manual checks in Part 1.
- The README Features section is updated: "Regions and roles" now says volunteers join with their region's code, with optional approval.
