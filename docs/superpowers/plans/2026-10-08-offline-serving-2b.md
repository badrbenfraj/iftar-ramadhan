# Spec 2B: Serving With No Network Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a volunteer serve with no network, where the region allows it. The meal is kept on the phone, synced later, and every double serve is recorded and shown, never silent.

**Architecture:**
- **Backend.** It gains a per-region `allowOfflineServing` flag and a batch sync endpoint, plus an admin review endpoint. Sync handles each event in its own transaction. It is idempotent by `clientEventId` and reuses 2A's `meal_events` table, where `source = 'offline'` and `conflict` were reserved for this.
- **App.** It keeps an encrypted queue of pending meals and items to review. One controller flushes the queue on four triggers (connectivity back, app resume, every 30 s while pending, pull-to-refresh). The scanner's "Can't check tonight" state gains **Serve offline**, with the same 5 s Undo as an online serve.

**Tech Stack:** NestJS + TypeORM + PostgreSQL 16; Flutter 3.44 / Dart 3.12, Riverpod 3, Dio 5, `cryptography` (already added in 2A).

**Spec:** [docs/superpowers/specs/2026-10-03-offline-serving-design.md](../specs/2026-10-03-offline-serving-design.md) (Spec 2B). It builds on Spec 2A, which is merged to `main` (`bd43ea4`).

## Global Constraints

- **No tests.** The user said "always ignore e2e and tests". Write, edit and run none. Verify with `npm run build` and `npm run lint` (backend) and `flutter gen-l10n && flutter analyze lib` (mobile). Test files under `test/` that stop compiling are out of scope.
- **Offline serving is off by default.** `regions.allowOfflineServing boolean NOT NULL DEFAULT false`. Only admins change it.
- **Sync bounds.** At most 200 events per request. `servedAt` must be no more than 5 min in the future and no more than 36 h in the past, otherwise the event is `rejected: CLOCK_OUT_OF_RANGE`.
- **Region policy at sync time.** A region with `allowOfflineServing = false` at sync time still gets the event **applied**, with `flag = 'OFFLINE_NOT_ALLOWED'`, because the meal already happened.
- **Result per event, in request order:** `applied` (optional `flag`) | `duplicate` | `conflict` (with `other: { servedAt, servedBy }`) | `rejected` (with `code`). Each event is processed in its own transaction.
- **Dual-write.** An `applied` offline event updates `fastings.takenMeals` and `lastTakenMeal` in the same transaction, as 2A does. A `conflict` event is stored with `conflict = true` and is never dual-written.
- **The queue holds person IDs and timestamps only**, never names. It lives in an encrypted file and survives app restarts.
- **Flush triggers:** connectivity regained, app resumed, every 30 s while items are pending, and pull-to-refresh.
- **App reactions to results:** `applied`/`duplicate` drop the item from the queue. `conflict` moves it to the review list. `rejected` moves it to the review list as a problem.
- **Logout with unsynced meals is blocked.** The dialog offers "Log out anyway (meals will be lost)" as an explicit, destructive choice.
- **First offline serve in a scanner session shows a dialog**, "Serve without checking?". Later serves in the same session skip it.
- **Copy:** every new string goes in en, fr and ar. Names use `isolate()`; times and IDs use `ltr()`; digits are Western.
- **No PII in backend logs.** Log IDs and counts only.
- **Encoding:** edit with the Edit/Write tools only. Every file stays UTF-8.

### Where the plan departs from the spec, and why
1. **Sync rejects other regions.** A volunteer syncing an event for another region gets `rejected: REGION_NOT_ALLOWED`. The spec says "the actor must belong to each event's region" but names no code. Admins are exempt.
2. **A retried conflict stays a conflict.** If a `clientEventId` is already stored as a conflict record, sync answers `conflict` again, not `duplicate`. Otherwise a lost response would hide the double serve from the phone.
3. **Unexpected errors fail the whole request.** A database or server error inside one event's transaction fails the request with a 5xx. The queue is kept and retried; retries are safe because they're idempotent. The spec's four statuses are reserved for answers about the meal itself.
4. **No region-change guard.** The app has no way to change region, so there's nothing to guard. Queued events carry their own `regionId` and sync regardless.
5. **Other users' meals on a shared phone.** They stay in the queue and sync when that user signs in again (the spec's open-question proposal). There's no "meals from {name}" banner (YAGNI).

## Review Focus

There are no tests (user override), so reviewers must trace these by reading the code:
1. **The same queued meal sent twice** (a lost response, then a retry) records **one** meal. The answer is `duplicate`, or `conflict` again if it was a conflict.
2. **Undo of an offline serve** within the first 5 s. If the meal is still queued, it is dropped. If a flush is in flight, Undo waits for its answer. If the meal already synced, Undo falls back to the server undo. The meal must never silently stay recorded.
3. **Two phones serve the same person offline.** One is `applied` and the other `conflict`. Both are stored, and the second phone shows "1 serving to review".
4. **A wrong phone clock** gives a review item that says "Check the phone's date and time". The item never loops forever in the queue.
5. **Logout with pending meals** is blocked unless "Log out anyway" is chosen. A session expiry keeps the queue.

## How to run things (Windows host, Git Bash, Docker Desktop running)

Backend build and lint:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W)/apps/backend:/app" -v iftar_backend_node_modules:/app/node_modules -w /app node:24-alpine sh -c "npm run build && npm run lint"
```

Mobile:

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/repo" -v iftar_pub_cache:/root/.pub-cache -w /repo/apps/mobile ghcr.io/cirruslabs/flutter:stable sh -c "flutter pub get >/dev/null && flutter gen-l10n && flutter analyze lib"
```

Run both from the repository root. The user's git hook adds `.prompts/archives/*.tar.br` files to commits; that's expected. Stage explicit paths only, and never stage `.prompts` deletions. Commit messages end with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 0: Branch and clean baseline

**Files:** none.

- [ ] **Step 1: Confirm the branch**

The branch `feat/offline-serving-2b` already exists at `main` (`bd43ea4`). Run `git status` and `git log --oneline -1`. Expected: on `feat/offline-serving-2b`, HEAD at `bd43ea4`.

- [ ] **Step 2: Clean baseline**

Run the backend build and lint command, then the mobile command. Expected: both clean. If either fails on `main`, stop and report it.

---

### Task 1: Backend: the per-region offline flag

**Files:**
- Create: `apps/backend/migrations/1791300000000-AddAllowOfflineServing.ts`
- Modify: `apps/backend/src/region/entities/region.entity.ts`
- Modify: `apps/backend/src/region/dtos/region-input.dto.ts`
- Modify: `apps/backend/src/region/dtos/region-output.dto.ts`
- Modify: `apps/backend/src/user/dtos/user-output.dto.ts` (`UserRegionOutput`)
- Modify: `apps/backend/src/region/services/region.service.ts` (`updateRegion`)

**Interfaces:**
- Produces:
  - The column `regions.allowOfflineServing` and the entity field `Region.allowOfflineServing: boolean`.
  - `UpdateRegionInput.allowOfflineServing?: boolean` and `CreateRegionInput.allowOfflineServing?: boolean`.
  - `allowOfflineServing` exposed on `RegionOutput` and `UserRegionOutput`, so `/users/me` and login carry it.

- [ ] **Step 1: Migration**

Create `apps/backend/migrations/1791300000000-AddAllowOfflineServing.ts`:

```ts
import { MigrationInterface, QueryRunner } from 'typeorm';

/** Spec 2B §3: offline serving is enabled region by region, off by default. */
export class AddAllowOfflineServing1791300000000 implements MigrationInterface {
  name = 'AddAllowOfflineServing1791300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "regions" ADD "allowOfflineServing" boolean NOT NULL DEFAULT false`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "regions" DROP COLUMN "allowOfflineServing"`,
    );
  }
}
```

- [ ] **Step 2: Entity and DTOs**

In `region.entity.ts`, add after `active`:

```ts
  /** Spec 2B: volunteers may serve with no network in this region. */
  @Column({ default: false })
  allowOfflineServing: boolean;
```

In `region-input.dto.ts`, add `IsOptional` to the class-validator import. Add this field to both `CreateRegionInput` and `UpdateRegionInput`, after `active`:

```ts
  @IsBoolean()
  @IsOptional()
  @ApiProperty({ required: false, description: 'Admins only (spec 2B)' })
  allowOfflineServing?: boolean;
```

In `region-output.dto.ts` (`RegionOutput`), and in `user-output.dto.ts` (`UserRegionOutput`), add after `active`:

```ts
  @Expose()
  @ApiProperty({ description: 'Volunteers may serve with no network (spec 2B)' })
  allowOfflineServing: boolean;
```

- [ ] **Step 3: Only admins change the policy**

In `region.service.ts` `updateRegion`, after the existing `isAllowed` check, add:

```ts
    // Offline serving trades double-serve safety for availability: an
    // admin decision (spec 2B §4.3).
    if (
      input.allowOfflineServing !== undefined &&
      input.allowOfflineServing !== region.allowOfflineServing &&
      !actor.roles.includes(ROLE.ADMIN)
    ) {
      throw new ForbiddenException('Only admins can change offline serving');
    }
```

Add `ForbiddenException` to the `@nestjs/common` import. Add `import { ROLE } from '../../auth/constants/role.constant';` if it isn't imported yet.

- [ ] **Step 4: Verify and commit**

Run the backend build and lint command. Expected: clean.

```bash
git add apps/backend/migrations/1791300000000-AddAllowOfflineServing.ts apps/backend/src/region apps/backend/src/user/dtos/user-output.dto.ts
git commit -m "feat(backend): per-region allowOfflineServing flag, off by default, admins only

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Backend: offline sync endpoint

**Files:**
- Modify: `apps/backend/src/fasting/constants/error-codes.ts`
- Create: `apps/backend/src/fasting/dtos/meal-sync.dto.ts`
- Modify: `apps/backend/src/fasting/services/meal-event.service.ts`
- Modify: `apps/backend/src/fasting/services/fasting.service.ts`
- Modify: `apps/backend/src/fasting/controllers/fasting.controller.ts`

**Interfaces:**
- Consumes:
  - 2A's `MealEventService` members: `findEvent`, `activeEventOn`, `serviceDay`, `toMealEventOutput`, `MealEventRow`, and `timeZone`.
  - Task 1's `regions.allowOfflineServing`.
- Produces:
  - `POST /fastings/meals/sync`, with body `{ events: SyncMealEventInput[] }` and response `{ data: MealSyncResultOutput[] }` in request order.
  - `MealEventService.syncOffline(ctx, events)`.
  - `MealEventService.insertEvent(manager, {...})`; `insertActive` now delegates to it.
  - The error codes `CLOCK_OUT_OF_RANGE` and `REGION_NOT_ALLOWED`, and `OFFLINE_FLAGS.OFFLINE_NOT_ALLOWED`.

- [ ] **Step 1: Codes**

In `error-codes.ts`, add to `FASTING_ERROR_CODES`:

```ts
  CLOCK_OUT_OF_RANGE: 'CLOCK_OUT_OF_RANGE',
  REGION_NOT_ALLOWED: 'REGION_NOT_ALLOWED',
```

and append:

```ts
/** Admin-review markers on meal events; they don't change validity. */
export const OFFLINE_FLAGS = {
  OFFLINE_NOT_ALLOWED: 'OFFLINE_NOT_ALLOWED',
} as const;
```

- [ ] **Step 2: DTOs**

Create `apps/backend/src/fasting/dtos/meal-sync.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsISO8601,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateNested,
} from 'class-validator';

import { MealServedByOutput } from './meal-event-output.dto';

/** One meal served with no network, as the phone recorded it. */
export class SyncMealEventInput {
  @IsUUID('4')
  @ApiProperty({ format: 'uuid' })
  clientEventId: string;

  @IsInt()
  @ApiProperty()
  fastingId: number;

  @IsInt()
  @ApiProperty()
  regionId: number;

  /** Device time of the hand-over. */
  @IsISO8601()
  @ApiProperty()
  servedAt: string;

  @IsString()
  @MaxLength(64)
  @IsOptional()
  @ApiProperty({ required: false, maxLength: 64 })
  deviceId?: string;
}

export class SyncMealsInput {
  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => SyncMealEventInput)
  @ApiProperty({ type: [SyncMealEventInput], maxItems: 200 })
  events: SyncMealEventInput[];
}

export type MealSyncStatus = 'applied' | 'duplicate' | 'conflict' | 'rejected';

export class MealSyncOtherOutput {
  @ApiProperty()
  servedAt: string;

  @ApiProperty({ type: MealServedByOutput, nullable: true })
  servedBy: MealServedByOutput | null;
}

/** What happened to one synced event (spec 2B §4.1). */
export class MealSyncResultOutput {
  @ApiProperty({ format: 'uuid' })
  clientEventId: string;

  @ApiProperty({ enum: ['applied', 'duplicate', 'conflict', 'rejected'] })
  status: MealSyncStatus;

  @ApiProperty({ required: false, description: 'Set when rejected' })
  code?: string;

  @ApiProperty({ required: false, description: 'Admin-review marker on an applied event' })
  flag?: string | null;

  @ApiProperty({ type: MealSyncOtherOutput, required: false, description: 'Set on conflict' })
  other?: MealSyncOtherOutput;
}
```

- [ ] **Step 3: Generalize the insert**

In `meal-event.service.ts`, replace `insertActive` with these two methods:

```ts
  /** Inserts a meal event and returns its ID. Does not dual-write. */
  async insertEvent(
    manager: EntityManager,
    event: {
      id: string | null;
      fastingId: number;
      regionId: number;
      servedAt: Date;
      servedByUserId: number;
      deviceId: string | null;
      source: 'online' | 'offline';
      conflict: boolean;
      flag: string | null;
    },
  ): Promise<string> {
    const [row] = await manager.query(
      `INSERT INTO "meal_events"
         ("id","fastingId","regionId","servedAt","serviceDay","servedByUserId","source","deviceId","conflict","flag")
       VALUES (COALESCE($1::uuid, gen_random_uuid()), $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING "id"`,
      [
        event.id,
        event.fastingId,
        event.regionId,
        event.servedAt,
        this.serviceDay(event.servedAt),
        event.servedByUserId,
        event.source,
        event.deviceId,
        event.conflict,
        event.flag,
      ],
    );
    return row.id;
  }

  /** Inserts an active online event and returns its ID. Does not dual-write. */
  insertActive(
    manager: EntityManager,
    event: {
      id: string | null;
      fastingId: number;
      regionId: number;
      servedAt: Date;
      servedByUserId: number;
      deviceId: string | null;
    },
  ): Promise<string> {
    return this.insertEvent(manager, {
      ...event,
      source: 'online',
      conflict: false,
      flag: null,
    });
  }
```

- [ ] **Step 4: The sync**

In `meal-event.service.ts`:

1. Add these imports:

```ts
import { ROLE } from '../../auth/constants/role.constant';
import { OFFLINE_FLAGS } from '../constants/error-codes';
import {
  MealSyncResultOutput,
  SyncMealEventInput,
} from '../dtos/meal-sync.dto';
```

`FASTING_ERROR_CODES` is already imported from `../constants/error-codes`. Merge the two into one import.

2. Add these module-level constants after `EVENT_SELECT`:

```ts
/** Offline meals older than this, or this far in the future, mean a wrong phone clock (spec 2B §4.1). */
const SYNC_PAST_LIMIT_MS = 36 * 60 * 60 * 1000;
const SYNC_FUTURE_LIMIT_MS = 5 * 60 * 1000;
```

3. Add these methods to the class:

```ts
  /**
   * Applies meals served with no network (spec 2B §4.1). Events are handled
   * in request order, each in its own transaction, and each gets a result.
   * Idempotent by clientEventId: a retried batch records nothing twice.
   */
  async syncOffline(
    ctx: RequestContext,
    events: SyncMealEventInput[],
  ): Promise<MealSyncResultOutput[]> {
    this.logger.log(
      ctx,
      `${this.syncOffline.name} was called with ${events.length} events`,
    );
    const actor: Actor = ctx.user;
    const isAdmin = actor.roles.includes(ROLE.ADMIN);
    const [me]: Array<{ regionId: number | null }> = await this.dataSource.query(
      `SELECT "regionId" FROM "users" WHERE "id" = $1`,
      [actor.id],
    );
    const results: MealSyncResultOutput[] = [];
    for (const event of events) {
      results.push(
        await this.syncOne(event, actor, isAdmin, me?.regionId ?? null),
      );
    }
    return results;
  }

  private async syncOne(
    event: SyncMealEventInput,
    actor: Actor,
    isAdmin: boolean,
    actorRegionId: number | null,
  ): Promise<MealSyncResultOutput> {
    const base = { clientEventId: event.clientEventId };
    const servedAt = new Date(event.servedAt);
    const now = Date.now();
    if (
      isNaN(servedAt.getTime()) ||
      servedAt.getTime() > now + SYNC_FUTURE_LIMIT_MS ||
      servedAt.getTime() < now - SYNC_PAST_LIMIT_MS
    ) {
      return {
        ...base,
        status: 'rejected',
        code: FASTING_ERROR_CODES.CLOCK_OUT_OF_RANGE,
      };
    }
    if (!isAdmin && actorRegionId !== event.regionId) {
      return {
        ...base,
        status: 'rejected',
        code: FASTING_ERROR_CODES.REGION_NOT_ALLOWED,
      };
    }

    return this.dataSource.transaction(
      async (manager): Promise<MealSyncResultOutput> => {
      const rows: Array<{ id: number; lastTakenMeal: Date | null }> =
        await manager.query(
          `SELECT "id", "lastTakenMeal" FROM "fastings"
           WHERE "id" = $1 AND "regionId" = $2
           FOR UPDATE`,
          [event.fastingId, event.regionId],
        );
      if (rows.length === 0) {
        return {
          ...base,
          status: 'rejected',
          code: FASTING_ERROR_CODES.PERSON_NOT_FOUND,
        };
      }

      const serviceDay = this.serviceDay(servedAt);
      const active = await this.activeEventOn(
        manager,
        event.fastingId,
        serviceDay,
      );
      const otherOf = (lastTakenMeal: Date | null) => ({
        servedAt: active
          ? toMealEventOutput(active).servedAt
          : (lastTakenMeal?.toISOString() ?? servedAt.toISOString()),
        servedBy: active ? toMealEventOutput(active).servedBy : null,
      });
      const lastTakenMeal = rows[0].lastTakenMeal
        ? new Date(rows[0].lastTakenMeal)
        : null;

      const existing = await this.findEvent(manager, event.clientEventId);
      if (existing) {
        if (existing.fastingId !== event.fastingId) {
          return {
            ...base,
            status: 'rejected',
            code: FASTING_ERROR_CODES.CLIENT_EVENT_ID_REUSED,
          };
        }
        // A retried conflict stays visible as a conflict on the phone.
        return existing.conflict
          ? { ...base, status: 'conflict', other: otherOf(lastTakenMeal) }
          : { ...base, status: 'duplicate' };
      }

      const servedThatDay =
        active ||
        (lastTakenMeal != null &&
          localDayKey(lastTakenMeal, this.timeZone) === serviceDay);
      const insert = {
        id: event.clientEventId,
        fastingId: event.fastingId,
        regionId: event.regionId,
        servedAt,
        servedByUserId: actor.id,
        deviceId: event.deviceId ?? null,
        source: 'offline' as const,
      };

      if (servedThatDay) {
        // A second physical hand-over: recorded, never dual-written.
        await this.insertEvent(manager, { ...insert, conflict: true, flag: null });
        return { ...base, status: 'conflict', other: otherOf(lastTakenMeal) };
      }

      const [region]: Array<{ allowOfflineServing: boolean }> =
        await manager.query(
          `SELECT "allowOfflineServing" FROM "regions" WHERE "id" = $1`,
          [event.regionId],
        );
      const flag = region?.allowOfflineServing
        ? null
        : OFFLINE_FLAGS.OFFLINE_NOT_ALLOWED;
      await this.insertEvent(manager, { ...insert, conflict: false, flag });
      // Dual-write. An offline meal may be older than the latest one, so
      // lastTakenMeal only moves forward.
      await manager.query(
        `UPDATE "fastings"
         SET "takenMeals" = array_append("takenMeals", $2::varchar),
             "lastTakenMeal" = CASE
               WHEN "lastTakenMeal" IS NULL OR "lastTakenMeal" < $3 THEN $3
               ELSE "lastTakenMeal" END,
             "updatedAt" = now()
         WHERE "id" = $1`,
        [event.fastingId, servedAt.toISOString(), servedAt],
      );
      return { ...base, status: 'applied', flag };
    },
    );
  }
```

- [ ] **Step 5: Service and route**

In `fasting.service.ts`, add the imports for `SyncMealEventInput` and `MealSyncResultOutput` from `../dtos/meal-sync.dto`. Add after `revokeMeal`:

```ts
  /** Meals served with no network (spec 2B §4.1). */
  syncOfflineMeals(
    ctx: RequestContext,
    events: SyncMealEventInput[],
  ): Promise<MealSyncResultOutput[]> {
    this.logger.log(ctx, `${this.syncOfflineMeals.name} was called`);
    return this.meals.syncOffline(ctx, events);
  }
```

In `fasting.controller.ts`, add the imports `SyncMealsInput` and `MealSyncResultOutput` from `../dtos/meal-sync.dto`. Add this method directly after `revokeMeal`:

```ts
  @Post('meals/sync')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Sync meals served with no network (spec 2B §4.1)',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    description: 'One result per event, in request order',
    type: SwaggerBaseApiResponse([MealSyncResultOutput]),
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async syncOfflineMeals(
    @ReqContext() ctx: RequestContext,
    @Body() input: SyncMealsInput,
  ): Promise<BaseApiResponse<MealSyncResultOutput[]>> {
    this.logger.log(ctx, `${this.syncOfflineMeals.name} was called`);
    const results = await this.fastingService.syncOfflineMeals(
      ctx,
      input.events,
    );
    return { data: results, meta: {} };
  }
```

- [ ] **Step 6: Verify and commit**

Run the backend build and lint command. Expected: clean.

```bash
git add apps/backend/src/fasting
git commit -m "feat(backend): offline meal sync — applied, duplicate, conflict or rejected per event

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Backend: admin review of conflicts and flagged meals

**Files:**
- Create: `apps/backend/src/fasting/dtos/meal-review-output.dto.ts`
- Modify: `apps/backend/src/fasting/services/meal-event.service.ts`
- Modify: `apps/backend/src/fasting/services/fasting.service.ts`
- Modify: `apps/backend/src/fasting/controllers/fasting.controller.ts`

**Interfaces:**
- Consumes: Task 2's conflict and flagged events.
- Produces: `GET /fastings/meals/review/:region?day=YYYY-MM-DD`. Admin only. It defaults to today in APP_TIMEZONE and returns `{ data: MealReviewItemOutput[] }`.

- [ ] **Step 1: DTO**

Create `apps/backend/src/fasting/dtos/meal-review-output.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';

import { MealServedByOutput } from './meal-event-output.dto';

/** A meal an admin should look at: a double serve, or a flagged meal. */
export class MealReviewItemOutput {
  @ApiProperty({ format: 'uuid' })
  eventId: string;

  @ApiProperty()
  fastingId: number;

  @ApiProperty()
  personName: string;

  @ApiProperty()
  servedAt: string;

  @ApiProperty({ type: MealServedByOutput, nullable: true })
  servedBy: MealServedByOutput | null;

  @ApiProperty({ enum: ['online', 'offline', 'backfill'] })
  source: string;

  @ApiProperty({ description: 'A second meal the same day' })
  conflict: boolean;

  @ApiProperty({ nullable: true, description: 'e.g. OFFLINE_NOT_ALLOWED' })
  flag: string | null;

  @ApiProperty({ nullable: true })
  revokedAt: string | null;
}
```

- [ ] **Step 2: Query**

Add this import to `meal-event.service.ts`:

```ts
import { MealReviewItemOutput } from '../dtos/meal-review-output.dto';
```

Then add this method:

```ts
  /** A region's meals needing admin attention on [day] (spec 2B §4.2). */
  async reviewItems(
    regionId: number,
    day: string,
  ): Promise<MealReviewItemOutput[]> {
    const rows: Array<{
      eventId: string;
      fastingId: number;
      firstName: string;
      lastName: string;
      servedAt: Date;
      servedByUserId: number | null;
      servedByName: string | null;
      source: string;
      conflict: boolean;
      flag: string | null;
      revokedAt: Date | null;
    }> = await this.dataSource.query(
      `SELECT e."id" AS "eventId", e."fastingId", f."firstName", f."lastName",
              e."servedAt", e."servedByUserId", u."name" AS "servedByName",
              e."source", e."conflict", e."flag", e."revokedAt"
       FROM "meal_events" e
       JOIN "fastings" f ON f."id" = e."fastingId"
       LEFT JOIN "users" u ON u."id" = e."servedByUserId"
       WHERE e."regionId" = $1 AND e."serviceDay" = $2
         AND (e."conflict" = true OR e."flag" IS NOT NULL)
       ORDER BY e."fastingId", e."servedAt"`,
      [regionId, day],
    );
    return rows.map((r) => ({
      eventId: r.eventId,
      fastingId: r.fastingId,
      personName: `${r.firstName} ${r.lastName}`.trim(),
      servedAt: new Date(r.servedAt).toISOString(),
      servedBy:
        r.servedByUserId == null
          ? null
          : { id: r.servedByUserId, name: r.servedByName ?? '' },
      source: r.source,
      conflict: r.conflict,
      flag: r.flag,
      revokedAt: r.revokedAt ? new Date(r.revokedAt).toISOString() : null,
    }));
  }
```

- [ ] **Step 3: Service and route**

In `fasting.service.ts`:

1. Import `MealReviewItemOutput`.
2. Add `parseDayKey` and `localDayKey` to the existing `local-day` import, if they aren't already there.
3. Add this method:

```ts
  /** Admin review of conflicts and flagged meals (spec 2B §4.2). */
  getMealReview(
    ctx: RequestContext,
    region: number,
    day?: string,
  ): Promise<MealReviewItemOutput[]> {
    this.logger.log(ctx, `${this.getMealReview.name} was called`);
    if (day !== undefined && parseDayKey(day) === null) {
      throw new BadRequestException('day must be YYYY-MM-DD');
    }
    const key = parseDayKey(day) ?? localDayKey(new Date(), this.timeZone);
    return this.meals.reviewItems(region, key);
  }
```

In `fasting.controller.ts`, add these imports:

```ts
import { ROLE } from '../../auth/constants/role.constant';
import { Roles } from '../../auth/decorators/role.decorator';
import { RolesGuard } from '../../auth/guards/roles.guard';
import { MealReviewItemOutput } from '../dtos/meal-review-output.dto';
```

Before writing the decorators, check the exact exported names with `grep -n "export" apps/backend/src/auth/decorators/role.decorator.ts apps/backend/src/auth/guards/roles.guard.ts`.

Add this method directly after `getFastingsStatisticsByRegion`:

```ts
  @Get('meals/review/:region')
  @ApiOperation({
    summary: 'Admin: double serves and flagged meals of a day (spec 2B §4.2)',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse([MealReviewItemOutput]),
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(ROLE.ADMIN)
  async getMealReview(
    @ReqContext() ctx: RequestContext,
    @Param('region') region: number,
    @Query('day') day?: string,
  ): Promise<BaseApiResponse<MealReviewItemOutput[]>> {
    this.logger.log(ctx, `${this.getMealReview.name} was called`);
    const items = await this.fastingService.getMealReview(ctx, region, day);
    return { data: items, meta: {} };
  }
```

- [ ] **Step 4: Verify and commit**

Run the backend build and lint command. Expected: clean.

```bash
git add apps/backend/src/fasting
git commit -m "feat(backend): admin review of double serves and flagged meals per day

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: App — offline domain, encrypted queue file, sync call

**Files:**
- Modify: `apps/mobile/lib/features/auth/domain/user.dart` (`Region`)
- Create: `apps/mobile/lib/features/offline/domain/offline_meal.dart`
- Create: `apps/mobile/lib/core/storage/encrypted_json_file.dart`
- Create: `apps/mobile/lib/features/offline/data/meal_queue_store.dart`
- Modify: `apps/mobile/lib/features/people/data/people_repository.dart`

**Interfaces:**
- Consumes:
  - Task 1's `allowOfflineServing` on the profile's region.
  - Task 2's `POST /fastings/meals/sync`.
  - 2A's `ApiClient.mutationTimeout` and `settingsStorageProvider`.
- Produces:
  - `Region.allowOfflineServing: bool`.
  - `PendingMeal` (`clientEventId`, `personId`, `regionId`, `servedAt`, `userId`, `deviceId?`; `toJson`, `fromJson`, `toSyncJson`).
  - `enum MealSyncStatus`, `MealSyncResult.fromJson`.
  - `ReviewItem` (`.from(PendingMeal, MealSyncResult)`, `toJson`/`fromJson`; codes `clockCode`, `notFoundCode`, `regionCode`).
  - `EncryptedJsonFile`.
  - `MealQueueSnapshot`, `MealQueueStore` (`load`/`save`), `EncryptedMealQueueStore`, `MemoryMealQueueStore`, `mealQueueStoreProvider`.
  - `PeopleRepository.syncMeals(List<PendingMeal>) → Future<List<MealSyncResult>>`.

- [ ] **Step 1: The region's policy**

In `user.dart`, give `Region` the new field:

```dart
class Region {
  const Region({
    required this.id,
    required this.name,
    this.allowOfflineServing = false,
  });

  factory Region.fromJson(Map<String, dynamic> json) => Region(
    id: (json['id'] as num).toInt(),
    name: (json['name'] as String?) ?? '',
    allowOfflineServing: json['allowOfflineServing'] == true,
  );

  final int id;
  final String name;

  /// Spec 2B: volunteers may serve with no network here. Off by default and
  /// from an older backend.
  final bool allowOfflineServing;
```

Leave `toJson`, `==` and `hashCode` as they are. `toJson` is the region reference sent with a person edit, and the cached profile is the raw server JSON.

- [ ] **Step 2: Domain**

Create `apps/mobile/lib/features/offline/domain/offline_meal.dart`:

```dart
/// A meal served with no network, waiting to sync (spec 2B §5.1). Person ID
/// and times only: the queue holds no names.
class PendingMeal {
  const PendingMeal({
    required this.clientEventId,
    required this.personId,
    required this.regionId,
    required this.servedAt,
    required this.userId,
    this.deviceId,
  });

  factory PendingMeal.fromJson(Map<String, dynamic> json) => PendingMeal(
    clientEventId: json['clientEventId'] as String,
    personId: (json['personId'] as num).toInt(),
    regionId: (json['regionId'] as num).toInt(),
    servedAt: DateTime.parse(json['servedAt'] as String).toLocal(),
    userId: (json['userId'] as num).toInt(),
    deviceId: json['deviceId'] as String?,
  );

  final String clientEventId;
  final int personId;
  final int regionId;

  /// Device time of the hand-over.
  final DateTime servedAt;

  /// The volunteer who served it; only they sync it.
  final int userId;
  final String? deviceId;

  Map<String, dynamic> toJson() => {
    'clientEventId': clientEventId,
    'personId': personId,
    'regionId': regionId,
    'servedAt': servedAt.toUtc().toIso8601String(),
    'userId': userId,
    'deviceId': deviceId,
  };

  /// One item of `POST /fastings/meals/sync`.
  Map<String, dynamic> toSyncJson() => {
    'clientEventId': clientEventId,
    'fastingId': personId,
    'regionId': regionId,
    'servedAt': servedAt.toUtc().toIso8601String(),
    'deviceId': ?deviceId,
  };
}

enum MealSyncStatus { applied, duplicate, conflict, rejected }

/// The server's answer for one synced meal (spec 2B §4.1).
class MealSyncResult {
  const MealSyncResult({
    required this.clientEventId,
    required this.status,
    this.code,
    this.flag,
    this.otherServedAt,
    this.otherServedByName,
  });

  factory MealSyncResult.fromJson(Map<String, dynamic> json) {
    final other = json['other'];
    final servedBy = other is Map ? other['servedBy'] : null;
    final at = other is Map ? other['servedAt'] : null;
    final name = servedBy is Map ? servedBy['name'] : null;
    return MealSyncResult(
      clientEventId: json['clientEventId'] as String,
      status: MealSyncStatus.values.asNameMap()[json['status']],
      code: json['code'] as String?,
      flag: json['flag'] as String?,
      otherServedAt: at is String ? DateTime.tryParse(at)?.toLocal() : null,
      otherServedByName:
          name is String && name.trim().isNotEmpty ? name.trim() : null,
    );
  }

  final String clientEventId;

  /// Null for a status this app doesn't know: the meal stays queued.
  final MealSyncStatus? status;
  final String? code;
  final String? flag;
  final DateTime? otherServedAt;
  final String? otherServedByName;
}

/// A synced meal the volunteer should see: a double serve, or a meal the
/// server could not record (spec 2B §5.3). Acknowledged on the phone only;
/// admins resolve it.
class ReviewItem {
  const ReviewItem({
    required this.clientEventId,
    required this.personId,
    required this.servedAt,
    required this.userId,
    required this.conflict,
    this.code,
    this.otherServedAt,
    this.otherServedByName,
  });

  factory ReviewItem.from(PendingMeal meal, MealSyncResult result) =>
      ReviewItem(
        clientEventId: meal.clientEventId,
        personId: meal.personId,
        servedAt: meal.servedAt,
        userId: meal.userId,
        conflict: result.status == MealSyncStatus.conflict,
        code: result.code,
        otherServedAt: result.otherServedAt,
        otherServedByName: result.otherServedByName,
      );

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    final other = json['otherServedAt'];
    return ReviewItem(
      clientEventId: json['clientEventId'] as String,
      personId: (json['personId'] as num).toInt(),
      servedAt: DateTime.parse(json['servedAt'] as String).toLocal(),
      userId: (json['userId'] as num).toInt(),
      conflict: json['conflict'] == true,
      code: json['code'] as String?,
      otherServedAt: other is String ? DateTime.tryParse(other)?.toLocal() : null,
      otherServedByName: json['otherServedByName'] as String?,
    );
  }

  static const clockCode = 'CLOCK_OUT_OF_RANGE';
  static const notFoundCode = 'PERSON_NOT_FOUND';
  static const regionCode = 'REGION_NOT_ALLOWED';

  final String clientEventId;
  final int personId;
  final DateTime servedAt;
  final int userId;

  /// True: a second meal the same day. False: not recorded, see [code].
  final bool conflict;
  final String? code;
  final DateTime? otherServedAt;
  final String? otherServedByName;

  Map<String, dynamic> toJson() => {
    'clientEventId': clientEventId,
    'personId': personId,
    'servedAt': servedAt.toUtc().toIso8601String(),
    'userId': userId,
    'conflict': conflict,
    'code': code,
    'otherServedAt': otherServedAt?.toUtc().toIso8601String(),
    'otherServedByName': otherServedByName,
  };
}
```

- [ ] **Step 3: Encrypted JSON file**

Create `apps/mobile/lib/core/storage/encrypted_json_file.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import '../settings/settings_storage.dart';

/// One JSON document kept AES-GCM encrypted in a file, with its 256-bit key
/// in the platform keystore. Writes run one after another. Best effort: a
/// storage error never throws.
class EncryptedJsonFile {
  EncryptedJsonFile({
    required this._directory,
    required this._keys,
    required this.fileName,
    required this.keyName,
  });

  final Future<Directory> Function() _directory;
  final SettingsStorage _keys;
  final String fileName;
  final String keyName;
  final AesGcm _algorithm = AesGcm.with256bits();
  Future<void> _queue = Future.value();

  Future<void> _enqueue(Future<void> Function() op) {
    final next = _queue.then((_) => op());
    _queue = next.catchError((_) {});
    return next;
  }

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  Future<SecretKey> _key({required bool create}) async {
    final stored = await _keys.read(keyName);
    if (stored != null) return SecretKey(base64Decode(stored));
    if (!create) throw StateError('No key for $fileName');
    final key = await _algorithm.newSecretKey();
    await _keys.write(keyName, base64Encode(await key.extractBytes()));
    return key;
  }

  /// The saved document, or null when there is none. A file that can't be
  /// read is moved aside (`<file>.unreadable`), never deleted: it may hold
  /// meals that were really served.
  Future<Object?> read() async {
    File? file;
    try {
      file = await _file();
      if (!await file.exists()) return null;
      final box = SecretBox.fromConcatenation(
        await file.readAsBytes(),
        nonceLength: _algorithm.nonceLength,
        macLength: _algorithm.macAlgorithm.macLength,
      );
      final clear = await _algorithm.decrypt(
        box,
        secretKey: await _key(create: false),
      );
      return jsonDecode(utf8.decode(clear));
    } on Object {
      try {
        await file?.rename('${file.path}.unreadable');
      } on Object {
        // Nothing more to do.
      }
      return null;
    }
  }

  Future<void> write(Object json) => _enqueue(() async {
    try {
      final box = await _algorithm.encrypt(
        utf8.encode(jsonEncode(json)),
        secretKey: await _key(create: true),
      );
      final file = await _file();
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(box.concatenation(), flush: true);
      await tmp.rename(file.path);
    } on Object {
      // Best effort: the in-memory state is unaffected.
    }
  });
}
```

- [ ] **Step 4: The queue store**

Create `apps/mobile/lib/features/offline/data/meal_queue_store.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/storage/encrypted_json_file.dart';
import '../domain/offline_meal.dart';

class MealQueueSnapshot {
  const MealQueueSnapshot({this.pending = const [], this.review = const []});

  final List<PendingMeal> pending;
  final List<ReviewItem> review;
}

/// Meals served offline and items to review, kept across restarts
/// (spec 2B §5.2). Not wiped on logout: unsynced meals are real meals.
abstract interface class MealQueueStore {
  Future<MealQueueSnapshot> load();
  Future<void> save(MealQueueSnapshot snapshot);
}

class EncryptedMealQueueStore implements MealQueueStore {
  EncryptedMealQueueStore(this._file);

  final EncryptedJsonFile _file;

  @override
  Future<MealQueueSnapshot> load() async {
    final json = await _file.read();
    if (json is! Map<String, dynamic>) return const MealQueueSnapshot();
    return MealQueueSnapshot(
      pending: [
        for (final m in (json['pending'] as List?) ?? const [])
          ?_parse(m, PendingMeal.fromJson),
      ],
      review: [
        for (final r in (json['review'] as List?) ?? const [])
          ?_parse(r, ReviewItem.fromJson),
      ],
    );
  }

  /// One bad entry must not drop the others.
  static T? _parse<T>(Object? json, T Function(Map<String, dynamic>) from) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return from(json);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(MealQueueSnapshot snapshot) => _file.write({
    'v': 1,
    'pending': [for (final m in snapshot.pending) m.toJson()],
    'review': [for (final r in snapshot.review) r.toJson()],
  });
}

/// In memory, for tests and previews.
class MemoryMealQueueStore implements MealQueueStore {
  MealQueueSnapshot saved = const MealQueueSnapshot();

  @override
  Future<MealQueueSnapshot> load() async => saved;

  @override
  Future<void> save(MealQueueSnapshot snapshot) async => saved = snapshot;
}

final mealQueueStoreProvider = Provider<MealQueueStore>(
  (ref) => EncryptedMealQueueStore(
    EncryptedJsonFile(
      directory: getApplicationDocumentsDirectory,
      keys: ref.watch(settingsStorageProvider),
      fileName: 'meal_queue.bin',
      keyName: 'meal_queue_key',
    ),
  ),
);
```

- [ ] **Step 5: The sync call**

In `people_repository.dart`, add `import '../../offline/domain/offline_meal.dart';`. Then add to the interface:

```dart
  /// Sends meals served with no network (spec 2B §4.1). One result per
  /// meal, in order.
  Future<List<MealSyncResult>> syncMeals(List<PendingMeal> meals);
```

and add to `ApiPeopleRepository`:

```dart
  @override
  Future<List<MealSyncResult>> syncMeals(List<PendingMeal> meals) async {
    final envelope = await _api.post(
      '/fastings/meals/sync',
      body: {
        'events': [for (final m in meals) m.toSyncJson()],
      },
      timeout: ApiClient.mutationTimeout,
    );
    return [for (final r in envelope.list) MealSyncResult.fromJson(r)];
  }
```

- [ ] **Step 6: Verify and commit**

Run the mobile command. Expected: `flutter analyze lib` reports no issues.

```bash
git add apps/mobile/lib/features/auth/domain/user.dart apps/mobile/lib/features/offline apps/mobile/lib/core/storage/encrypted_json_file.dart apps/mobile/lib/features/people/data/people_repository.dart
git commit -m "feat(mobile): offline meal domain, encrypted queue file, sync call

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: App — the offline queue controller and its flush triggers

**Files:**
- Create: `apps/mobile/lib/features/offline/presentation/offline_queue_controller.dart`
- Modify: `apps/mobile/lib/app.dart`

**Interfaces:**
- Consumes:
  - Task 4's store, domain and `syncMeals`.
  - 2A's `connectivityProvider`, `authControllerProvider` and `peopleListProvider.refresh()`.
- Produces:
  - `OfflineQueueState` (`pending`, `review`, `syncing`, `lastSynced: SyncedNotice?`, `pendingFor(int? userId)`, `reviewFor(int? userId)`).
  - `SyncedNotice(count)`.
  - `OfflineQueueController`, with:
    - `enqueue(PendingMeal)`.
    - `remove(String clientEventId) → Future<bool>`.
    - `acknowledge(String clientEventId)`.
    - `discardFor(int userId)`.
    - `flush() → Future<int>`.
  - `offlineQueueProvider`.

- [ ] **Step 1: The controller**

Create `apps/mobile/lib/features/offline/presentation/offline_queue_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/connectivity.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../people/data/people_repository.dart';
import '../../people/presentation/people_controller.dart';
import '../data/meal_queue_store.dart';
import '../domain/offline_meal.dart';

/// Shown once as "{n} offline meals synced". A new object every time.
class SyncedNotice {
  SyncedNotice(this.count);
  final int count;
}

class OfflineQueueState {
  const OfflineQueueState({
    this.pending = const [],
    this.review = const [],
    this.syncing = false,
    this.lastSynced,
  });

  final List<PendingMeal> pending;
  final List<ReviewItem> review;
  final bool syncing;
  final SyncedNotice? lastSynced;

  List<PendingMeal> pendingFor(int? userId) => [
    for (final m in pending)
      if (m.userId == userId) m,
  ];

  List<ReviewItem> reviewFor(int? userId) => [
    for (final r in review)
      if (r.userId == userId) r,
  ];

  OfflineQueueState copyWith({
    List<PendingMeal>? pending,
    List<ReviewItem>? review,
    bool? syncing,
    SyncedNotice? lastSynced,
  }) => OfflineQueueState(
    pending: pending ?? this.pending,
    review: review ?? this.review,
    syncing: syncing ?? this.syncing,
    lastSynced: lastSynced ?? this.lastSynced,
  );
}

/// Meals served with no network and their sync (spec 2B §5.2). Flushed when
/// the connection comes back, when the app resumes, every [flushEvery]
/// while meals are pending, and on pull-to-refresh. Each volunteer syncs
/// only their own meals.
class OfflineQueueController extends Notifier<OfflineQueueState> {
  OfflineQueueController({this.flushEvery = const Duration(seconds: 30)});

  final Duration flushEvery;

  /// Matches the server's batch limit.
  static const batchSize = 200;

  Timer? _timer;
  Future<void>? _restoring;

  /// Completes when the flush in progress, if any, is over.
  Future<void>? _flushing;

  MealQueueStore get _store => ref.read(mealQueueStoreProvider);

  int? get _userId => ref.read(authControllerProvider).value?.id;

  @override
  OfflineQueueState build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(connectivityProvider, (previous, online) {
      if (previous == false && online) unawaited(flush());
    });
    ref.listen(authControllerProvider.select((a) => a.value?.id), (_, _) {
      _schedule();
      unawaited(flush());
    });
    _restoring = _restore();
    return const OfflineQueueState();
  }

  Future<void> _restore() async {
    final saved = await _store.load();
    if (!ref.mounted) return;
    // Anything queued before the file was read is kept as well.
    state = state.copyWith(
      pending: [...saved.pending, ...state.pending],
      review: [...saved.review, ...state.review],
    );
    _schedule();
    unawaited(flush());
  }

  Future<void> _ready() => _restoring ?? Future<void>.value();

  Future<void> enqueue(PendingMeal meal) async {
    await _ready();
    state = state.copyWith(pending: [...state.pending, meal]);
    await _persist();
    _schedule();
  }

  /// Undo of an offline serve. False when the meal already left the queue:
  /// it was synced, and only the server can undo it now.
  Future<bool> remove(String clientEventId) async {
    await _ready();
    // A meal already sent in a flush may be on the server: wait for its
    // answer instead of dropping it locally.
    await _flushing;
    final kept = [
      for (final m in state.pending)
        if (m.clientEventId != clientEventId) m,
    ];
    if (kept.length == state.pending.length) return false;
    state = state.copyWith(pending: kept);
    await _persist();
    _schedule();
    return true;
  }

  Future<void> acknowledge(String clientEventId) async {
    await _ready();
    state = state.copyWith(
      review: [
        for (final r in state.review)
          if (r.clientEventId != clientEventId) r,
      ],
    );
    await _persist();
  }

  /// "Log out anyway": this volunteer's unsynced meals and review items are
  /// dropped. Other volunteers' entries on this phone are kept.
  Future<void> discardFor(int userId) async {
    await _ready();
    state = state.copyWith(
      pending: [
        for (final m in state.pending)
          if (m.userId != userId) m,
      ],
      review: [
        for (final r in state.review)
          if (r.userId != userId) r,
      ],
    );
    await _persist();
    _schedule();
  }

  /// Sends the signed-in volunteer's pending meals. Returns how many were
  /// applied. On any failure everything stays queued for the next trigger.
  Future<int> flush() async {
    await _ready();
    if (!ref.mounted) return 0;
    final userId = _userId;
    final batch = state.pendingFor(userId).take(batchSize).toList();
    if (state.syncing || userId == null || batch.isEmpty) return 0;
    state = state.copyWith(syncing: true);
    final finished = Completer<void>();
    _flushing = finished.future;
    var applied = 0;
    try {
      final results = await ref
          .read(peopleRepositoryProvider)
          .syncMeals(batch);
      if (!ref.mounted) return 0;
      final byId = {for (final r in results) r.clientEventId: r};
      final done = <String>{};
      final toReview = <ReviewItem>[];
      for (final meal in batch) {
        final result = byId[meal.clientEventId];
        switch (result?.status) {
          case MealSyncStatus.applied:
            applied++;
            done.add(meal.clientEventId);
          case MealSyncStatus.duplicate:
            done.add(meal.clientEventId);
          case MealSyncStatus.conflict || MealSyncStatus.rejected:
            done.add(meal.clientEventId);
            toReview.add(ReviewItem.from(meal, result!));
          case null:
            // No usable answer for this meal: it stays queued.
            break;
        }
      }
      state = state.copyWith(
        pending: [
          for (final m in state.pending)
            if (!done.contains(m.clientEventId)) m,
        ],
        review: [...state.review, ...toReview],
        lastSynced: applied > 0 ? SyncedNotice(applied) : null,
      );
      await _persist();
      if (done.isNotEmpty) unawaited(_refreshList());
    } on AppFailure {
      // No network, expired session or server trouble: kept for later.
    } finally {
      finished.complete();
      if (ref.mounted) {
        state = state.copyWith(syncing: false);
        _schedule();
      }
    }
    return applied;
  }

  /// The list on screen reflects the server after a sync.
  Future<void> _refreshList() async {
    try {
      if (ref.exists(peopleListProvider)) {
        await ref.read(peopleListProvider.notifier).refresh();
      }
    } on Object {
      // The list keeps its local copy; the next refresh catches up.
    }
  }

  Future<void> _persist() => _store.save(
    MealQueueSnapshot(pending: state.pending, review: state.review),
  );

  /// The periodic flush runs only while this volunteer has meals pending.
  void _schedule() {
    if (state.pendingFor(_userId).isEmpty) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(flushEvery, (_) => unawaited(flush()));
    }
  }
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueueController, OfflineQueueState>(
      OfflineQueueController.new,
    );
```

- [ ] **Step 2: Start it with the app, flush on resume**

In `apps/mobile/lib/app.dart`:
1. Add `import 'features/offline/presentation/offline_queue_controller.dart';`.
2. In `initState`'s post-frame callback, after the update check, add:

```dart
      // Restores meals served offline before a restart and starts syncing.
      ref.read(offlineQueueProvider);
```

3. In `_onResume`, before the `peopleListProvider` check, add:

```dart
    unawaited(ref.read(offlineQueueProvider.notifier).flush());
```

- [ ] **Step 3: Verify and commit**

Run the mobile command. Expected: no issues in `lib/`.

```bash
git add apps/mobile/lib/features/offline/presentation/offline_queue_controller.dart apps/mobile/lib/app.dart
git commit -m "feat(mobile): offline meal queue — persisted, flushed on reconnect, resume and every 30 s

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 6: App — "Serve offline" in the scanner

**Files:**
- Modify: `apps/mobile/lib/features/scan/presentation/scan_controller.dart`
- Modify: `apps/mobile/lib/features/scan/presentation/scan_result_panel.dart`
- Modify: `apps/mobile/lib/features/scan/presentation/scan_page.dart` (`_TopBar`)
- Modify: the 3 ARB files (+ the regenerated `app_localizations*.dart`)

**Interfaces:**
- Consumes:
  - Task 5's `offlineQueueProvider` (`enqueue`, `remove`, `pendingFor`).
  - Task 4's `PendingMeal` and `Region.allowOfflineServing`.
  - 2A's `ScanUnverified`, `ScanConfirming(person, clientEventId:, noCard:)`, `_onConfirmed`, `undo()`, `_revoke`, `deviceIdProvider`, `newUuidV4` and `MealEvent`.
- Produces:
  - `ScanConfirmed(person, {undoing, offline})`.
  - `ScanController.needsOfflineConsent`.
  - `ScanController.serveOffline(int personId)`.
  - The strings `serveOffline`, `serveOfflineTitle`, `serveOfflineBody`, `savedOnPhone` and `toSync(count)`.

- [ ] **Step 1: Controller**

In `scan_controller.dart`:

1. Add these imports:

```dart
import '../../offline/domain/offline_meal.dart';
import '../../offline/presentation/offline_queue_controller.dart';
```

2. Replace `ScanConfirmed` with:

```dart
final class ScanConfirmed extends ScanStatus {
  const ScanConfirmed(this.person, {this.undoing = false, this.offline = false});
  final FastingPerson person;

  /// Undo was tapped and hasn't finished yet.
  final bool undoing;

  /// Served with no network: saved on this phone, synced later (spec 2B).
  final bool offline;
}
```

3. Add these fields to `ScanController`, after `_historyUndoInFlight`:

```dart
  /// "Serve without checking?" was accepted in this scanner session
  /// (spec 2B §5.1); later offline serves skip the question.
  bool _offlineConsent = false;

  /// The person as the phone knew them before an offline serve, restored by
  /// its Undo.
  final Map<String, FastingPerson> _offlineOriginals = {};
```

4. Change `_onConfirmed`'s signature to `void _onConfirmed(FastingPerson person, {bool offline = false})`. In its body, change `status: ScanConfirmed(person),` to `status: ScanConfirmed(person, offline: offline),`.

5. Add these members after `_onConfirmed`:

```dart
  /// Whether "Serve offline" must first ask "Serve without checking?".
  bool get needsOfflineConsent => !_offlineConsent;

  /// "Serve offline" on "Can't check tonight" (spec 2B §5.1). Only where the
  /// region allows it. The meal is queued on this phone with a fresh
  /// clientEventId, and the person is marked served on the phone's list.
  Future<void> serveOffline(int personId) async {
    final current = state.status;
    if (current is! ScanUnverified || current.person.id != personId) return;
    final user = ref.read(authControllerProvider).value;
    final region = user?.region;
    if (user == null || region == null || !region.allowOfflineServing) {
      return;
    }
    _offlineConsent = true;
    final person = current.person;
    final now = _now();
    final eventId = newUuidV4();
    // Blocks the camera while the meal is being saved.
    _set(
      ScanConfirming(person, clientEventId: eventId, noCard: current.noCard),
    );
    final deviceId = await ref.read(deviceIdProvider.future);
    if (!ref.mounted) return;
    await ref
        .read(offlineQueueProvider.notifier)
        .enqueue(
          PendingMeal(
            clientEventId: eventId,
            personId: person.id,
            regionId: region.id,
            servedAt: now,
            userId: user.id,
            deviceId: deviceId,
          ),
        );
    if (!ref.mounted) return;
    _offlineOriginals[eventId] = person;
    _onConfirmed(
      person.copyWith(
        lastTakenMeal: now,
        takenMeals: [now, ...person.takenMeals],
        mealTakenTodayFromServer: true,
        receivedAt: now,
        todayMeal: MealEvent(
          eventId: eventId,
          servedAt: now,
          servedById: user.id,
          servedByName: user.name,
        ),
      ),
      offline: true,
    );
  }
```

6. In `undo()`:
   - Change `_set(ScanConfirmed(status.person, undoing: true));` to `_set(ScanConfirmed(status.person, undoing: true, offline: status.offline));`.
   - Change `final notice = await _revoke(meal.eventId, status.person);` to:

```dart
    final notice = status.offline
        ? await _undoOffline(meal.eventId, status.person)
        : await _revoke(meal.eventId, status.person);
```

7. Add after `_revoke`:

```dart
  /// Undo of an offline serve. Still queued: dropped on the phone, no network
  /// needed. Already synced meanwhile: undone on the server like any meal.
  Future<ScanNotice> _undoOffline(String eventId, FastingPerson person) async {
    final original = _offlineOriginals.remove(eventId);
    final removed = await ref
        .read(offlineQueueProvider.notifier)
        .remove(eventId);
    if (!removed) return _revoke(eventId, person);
    if (ref.mounted && original != null) {
      ref.read(peopleListProvider.notifier).upsert(original);
    }
    return ScanNotice(ScanNoticeKind.undone, name: person.fullName);
  }
```

- [ ] **Step 2: Panel**

In `scan_result_panel.dart`:

1. Make sure `auth_controller.dart` is imported (it already is in 2A).

2. In the `ScanUnverified` case, replace its `footer:` list with:

```dart
          footer: [
            if (ref.read(authControllerProvider).value?.region?.allowOfflineServing == true) ...[
              FilledButton.icon(
                onPressed: () => _serveOffline(context, controller, person.id),
                icon: const Icon(Icons.cloud_off_rounded),
                label: Text(l.serveOffline),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: controller.retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.retry),
              ),
            ] else
              FilledButton.icon(
                onPressed: controller.retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.retry),
              ),
            _Links([(l.skip, controller.scanNext)]),
          ],
```

3. Replace the `ScanConfirmed` case with:

```dart
      case ScanConfirmed(:final person, :final undoing, :final offline):
        return _DoneBand(
          person: person,
          undoing: undoing,
          offline: offline,
          undoWindow: ref.read(scanTimingsProvider).undoWindow,
          // No meal ID (older backend): nothing the server could undo.
          onUndo: person.todayMeal == null ? null : controller.undo,
        );
```

4. In `_DoneBand`:
   - Add `required this.offline,` to the constructor and `final bool offline;` to the fields.
   - In its inner `Column`, directly after the `servedLine` `Text`, add:

```dart
                        if (offline)
                          Text(
                            l.savedOnPhone,
                            style: const TextStyle(color: AppPalette.gold, fontSize: 12.5),
                          ),
```

5. Add this top-level function next to `_openOver`:

```dart
/// Asks "Serve without checking?" the first time in a scanner session
/// (spec 2B §5.1), then serves offline.
Future<void> _serveOffline(
  BuildContext context,
  ScanController controller,
  int personId,
) async {
  if (controller.needsOfflineConsent) {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.serveOfflineTitle),
        content: Text(l.serveOfflineBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.serveOffline),
          ),
        ],
      ),
    );
    if (ok != true) return;
  }
  await controller.serveOffline(personId);
}
```

- [ ] **Step 3: "{n} to sync" in the scanner's top bar**

In `scan_page.dart`:
1. Add the imports `../../offline/presentation/offline_queue_controller.dart` and `../../auth/presentation/auth_controller.dart` (if it isn't imported already).
2. In `build`, compute:

```dart
    final userId = ref.watch(authControllerProvider.select((a) => a.value?.id));
    final toSync = ref.watch(
      offlineQueueProvider.select((s) => s.pendingFor(userId).length),
    );
```

3. Pass `toSync: toSync,` to `_TopBar(...)`. Add `required this.toSync,` and `final int toSync;` to `_TopBar`.
4. In `_TopBar.build`, replace the `Text(l.servedTonight(servedTonight), …)` with:

```dart
                Text(
                  toSync > 0
                      ? '${l.servedTonight(servedTonight)} · ${l.toSync(toSync)}'
                      : l.servedTonight(servedTonight),
                  style: const TextStyle(color: AppPalette.gold, fontSize: 11.5),
                ),
```

- [ ] **Step 4: Strings**

`app_en.arb`:

```json
  "serveOffline": "Serve offline",
  "serveOfflineTitle": "Serve without checking?",
  "serveOfflineBody": "Only do this if no other volunteer is serving this region right now. The meal is saved on this phone and syncs when you’re back online. If it turns out to be a second meal, it will be reported.",
  "savedOnPhone": "Saved on this phone. Syncs when online.",
  "toSync": "{count, plural, =1{1 to sync} other{{count} to sync}}",
  "@toSync": {"placeholders": {"count": {"type": "int"}}},
```

`app_fr.arb`:

```json
  "serveOffline": "Servir hors ligne",
  "serveOfflineTitle": "Servir sans vérifier ?",
  "serveOfflineBody": "À faire seulement si aucun autre bénévole ne sert cette région en ce moment. Le repas est enregistré sur ce téléphone et sera synchronisé au retour du réseau. S’il s’agit d’un deuxième repas, ce sera signalé.",
  "savedOnPhone": "Enregistré sur ce téléphone. Synchronisé au retour du réseau.",
  "toSync": "{count, plural, =1{1 à synchroniser} other{{count} à synchroniser}}",
```

`app_ar.arb`:

```json
  "serveOffline": "التقديم دون اتصال",
  "serveOfflineTitle": "التقديم دون تحقق؟",
  "serveOfflineBody": "افعل ذلك فقط إن لم يكن متطوع آخر يوزّع في هذه المنطقة الآن. تُحفظ الوجبة على هذا الهاتف وتُزامَن عند عودة الاتصال. وإن تبيّن أنها وجبة ثانية فسيُبلَّغ عنها.",
  "savedOnPhone": "حُفظت على هذا الهاتف. تُزامَن عند عودة الاتصال.",
  "toSync": "{count, plural, =1{1 في انتظار المزامنة} other{{count} في انتظار المزامنة}}",
```

- [ ] **Step 5: Verify and commit**

Run the mobile command (it includes `flutter gen-l10n`). Expected: no issues in `lib/`.

```bash
git add apps/mobile/lib/features/scan apps/mobile/lib/l10n
git commit -m "feat(mobile): Serve offline from \"Can't check tonight\", with first-time question and Undo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: App — "servings to review", the sync toast, pull-to-refresh sync

**Files:**
- Create: `apps/mobile/lib/features/offline/presentation/review_sheet.dart`
- Modify: `apps/mobile/lib/features/people/presentation/people_list_page.dart`
- Modify: `apps/mobile/lib/shell/home_shell.dart`
- Modify: the 3 ARB files (+ the regenerated localization files)

**Interfaces:**
- Consumes: Task 5's `offlineQueueProvider` (`reviewFor`, `acknowledge`, `flush`, `lastSynced`); 2A's `formatSavedAt`, `isolate`, `ltr` and `showAppSnackBar`.
- Produces:
  - `showReviewSheet(BuildContext)`.
  - The strings `offlineSynced(count)`, `toReview(count)`, `reviewTitle`, `reviewServedAt(time)`, `reviewConflict(time, name)`, `reviewConflictNoName(time)`, `reviewClock`, `reviewNotFound`, `reviewRegion`, `reviewOther` and `acknowledge`.

- [ ] **Step 1: The review sheet**

Create `apps/mobile/lib/features/offline/presentation/review_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../people/domain/fasting_person.dart';
import '../../people/presentation/people_controller.dart';
import '../domain/offline_meal.dart';
import 'offline_queue_controller.dart';

/// "Servings to review" (spec 2B §5.3): double serves and meals the server
/// could not record. Acknowledging only clears them from this phone; the
/// server keeps them for admins.
Future<void> showReviewSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _ReviewSheet(),
);

class _ReviewSheet extends ConsumerWidget {
  const _ReviewSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final userId = ref.watch(authControllerProvider.select((a) => a.value?.id));
    final items = ref.watch(
      offlineQueueProvider.select((s) => s.reviewFor(userId)),
    );
    final people = {
      for (final p in ref.watch(peopleListProvider).value ?? const <FastingPerson>[])
        p.id: p,
    };
    final now = ref.watch(clockProvider)();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              l.reviewTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.conflict ? Icons.people_alt_outlined : Icons.error_outline,
                color: c.clayInk,
              ),
              title: Text(
                switch (people[item.personId]) {
                  final p? => isolate(p.fullName),
                  null => ltr('#${item.personId}'),
                },
              ),
              subtitle: Text(
                [
                  l.reviewServedAt(ltr(formatSavedAt(item.servedAt, now))),
                  _reason(l, item, now),
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () async {
                  final last = items.length == 1;
                  await ref
                      .read(offlineQueueProvider.notifier)
                      .acknowledge(item.clientEventId);
                  if (last && context.mounted) Navigator.pop(context);
                },
                child: Text(l.acknowledge),
              ),
            ),
        ],
      ),
    );
  }

  static String _reason(AppLocalizations l, ReviewItem item, DateTime now) {
    if (item.conflict) {
      final at = item.otherServedAt;
      final name = item.otherServedByName;
      if (at == null) return l.reviewConflictNoName(ltr('—'));
      final time = ltr(formatSavedAt(at, now));
      return name == null
          ? l.reviewConflictNoName(time)
          : l.reviewConflict(time, isolate(name));
    }
    return switch (item.code) {
      ReviewItem.clockCode => l.reviewClock,
      ReviewItem.notFoundCode => l.reviewNotFound,
      ReviewItem.regionCode => l.reviewRegion,
      _ => l.reviewOther,
    };
  }
}
```

The `context.colors` extension and `AppSpacing` come from the theme files this import list already names. Check that `clayInk` exists with `grep -n "clayInk" apps/mobile/lib/core/theme/iftar_colors.dart`. If it doesn't, use the same ink colour `scan_result_panel.dart` uses for the Already-served note.

- [ ] **Step 2: People — the banner and sync on pull-to-refresh**

In `people_list_page.dart`:
1. Add the imports `../../offline/presentation/offline_queue_controller.dart`, `../../offline/presentation/review_sheet.dart` and `../../auth/presentation/auth_controller.dart` (if not already imported), plus `dart:async`.
2. In `_refresh()`, add this as the first line of the `try` body:

```dart
      unawaited(ref.read(offlineQueueProvider.notifier).flush());
```

3. In `build`, after the `syncNote` computation, add:

```dart
    final userId = ref.watch(authControllerProvider.select((a) => a.value?.id));
    final toReview = ref.watch(
      offlineQueueProvider.select((s) => s.reviewFor(userId).length),
    );
```

4. In the `slivers:` list, directly after the `if (syncNote != null) SliverToBoxAdapter(...)` entry, add:

```dart
            if (toReview > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 0),
                  child: Material(
                    color: context.colors.claySoft,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showReviewSheet(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.fact_check_outlined, size: 18, color: context.colors.clayInk),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l.toReview(toReview),
                                style: TextStyle(color: context.colors.clayInk, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: context.colors.clayInk),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
```

- [ ] **Step 3: The sync toast**

In `home_shell.dart`:
1. Add these imports:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/state_views.dart';
import '../features/offline/presentation/offline_queue_controller.dart';
```

2. Change `class HomeShell extends StatelessWidget` to `class HomeShell extends ConsumerWidget`, and its `build(BuildContext context)` to `build(BuildContext context, WidgetRef ref)`.
3. At the top of that `build`, add:

```dart
    // "{n} offline meals synced" (spec 2B §5.2), once per sync.
    ref.listen(offlineQueueProvider.select((s) => s.lastSynced), (prev, next) {
      if (next == null || identical(prev, next)) return;
      showAppSnackBar(context, AppLocalizations.of(context).offlineSynced(next.count));
    });
```

`AppLocalizations` is already imported in this file.

- [ ] **Step 4: Strings**

`app_en.arb`:

```json
  "offlineSynced": "{count, plural, =1{1 offline meal synced} other{{count} offline meals synced}}",
  "@offlineSynced": {"placeholders": {"count": {"type": "int"}}},
  "toReview": "{count, plural, =1{1 serving to review} other{{count} servings to review}}",
  "@toReview": {"placeholders": {"count": {"type": "int"}}},
  "reviewTitle": "Servings to review",
  "reviewServedAt": "Served offline at {time}",
  "@reviewServedAt": {"placeholders": {"time": {"type": "String"}}},
  "reviewConflict": "Also served at {time} by {name}",
  "@reviewConflict": {"placeholders": {"time": {"type": "String"}, "name": {"type": "String"}}},
  "reviewConflictNoName": "Also served at {time}",
  "@reviewConflictNoName": {"placeholders": {"time": {"type": "String"}}},
  "reviewClock": "Check the phone’s date and time",
  "reviewNotFound": "This person isn’t in this region",
  "reviewRegion": "Served for another region",
  "reviewOther": "Couldn’t be saved",
  "acknowledge": "Acknowledge",
```

`app_fr.arb`:

```json
  "offlineSynced": "{count, plural, =1{1 repas hors ligne synchronisé} other{{count} repas hors ligne synchronisés}}",
  "toReview": "{count, plural, =1{1 service à vérifier} other{{count} services à vérifier}}",
  "reviewTitle": "Services à vérifier",
  "reviewServedAt": "Servi hors ligne à {time}",
  "reviewConflict": "Déjà servi à {time} par {name}",
  "reviewConflictNoName": "Déjà servi à {time}",
  "reviewClock": "Vérifiez la date et l’heure du téléphone",
  "reviewNotFound": "Cette personne n’est pas dans cette région",
  "reviewRegion": "Servi pour une autre région",
  "reviewOther": "N’a pas pu être enregistré",
  "acknowledge": "J’ai compris",
```

`app_ar.arb`:

```json
  "offlineSynced": "{count, plural, =1{زومنت وجبة واحدة قُدّمت دون اتصال} other{زومنت {count} وجبات قُدّمت دون اتصال}}",
  "toReview": "{count, plural, =1{تقديم واحد للمراجعة} other{{count} تقديمات للمراجعة}}",
  "reviewTitle": "تقديمات للمراجعة",
  "reviewServedAt": "قُدّمت دون اتصال على الساعة {time}",
  "reviewConflict": "استلم أيضًا على الساعة {time}، قدّمها {name}",
  "reviewConflictNoName": "استلم أيضًا على الساعة {time}",
  "reviewClock": "تحقق من تاريخ الهاتف وساعته",
  "reviewNotFound": "هذا الشخص ليس في هذه المنطقة",
  "reviewRegion": "قُدّمت لمنطقة أخرى",
  "reviewOther": "تعذّر حفظها",
  "acknowledge": "فهمت",
```

- [ ] **Step 5: Verify and commit**

Run the mobile command. Expected: no issues in `lib/`.

```bash
git add apps/mobile/lib/features/offline/presentation/review_sheet.dart apps/mobile/lib/features/people/presentation/people_list_page.dart apps/mobile/lib/shell/home_shell.dart apps/mobile/lib/l10n
git commit -m "feat(mobile): servings to review, offline-synced toast, pull-to-refresh syncs

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: App — logout guard for unsynced meals

**Files:**
- Modify: `apps/mobile/lib/features/profile/presentation/profile_page.dart` (`_logout`)
- Modify: the 3 ARB files (+ the regenerated localization files)

**Interfaces:**
- Consumes: Task 5's `offlineQueueProvider` (`flush`, `pendingFor`, `discardFor`).
- Produces: the strings `unsyncedTitle`, `unsyncedBody(count)` and `logoutAnyway`.

- [ ] **Step 1: The guard**

In `profile_page.dart`:
1. Add the import `../../offline/presentation/offline_queue_controller.dart`.
2. At the start of `_logout()`, after `final l = AppLocalizations.of(context);`, insert:

```dart
    // Unsynced meals are real meals: try once more, then make losing them
    // an explicit choice (spec 2B §5.4).
    final userId = ref.read(authControllerProvider).value?.id;
    final queue = ref.read(offlineQueueProvider.notifier);
    if (userId != null) {
      await queue.flush();
      if (!mounted) return;
      final unsynced = ref.read(offlineQueueProvider).pendingFor(userId).length;
      if (unsynced > 0) {
        final anyway = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.unsyncedTitle),
            content: Text(l.unsyncedBody(unsynced)),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.logoutAnyway),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
            ],
          ),
        );
        if (anyway != true) return;
        await queue.discardFor(userId);
        await ref.read(authControllerProvider.notifier).logout();
        return;
      }
    }
```

The existing confirmation dialog and logout follow unchanged, for the case with nothing unsynced.

- [ ] **Step 2: Strings**

`app_en.arb`:

```json
  "unsyncedTitle": "Meals not synced yet",
  "unsyncedBody": "{count, plural, =1{1 meal hasn’t synced yet.} other{{count} meals haven’t synced yet.}} Connect to sync before logging out.",
  "@unsyncedBody": {"placeholders": {"count": {"type": "int"}}},
  "logoutAnyway": "Log out anyway (meals will be lost)",
```

`app_fr.arb`:

```json
  "unsyncedTitle": "Repas non synchronisés",
  "unsyncedBody": "{count, plural, =1{1 repas n’est pas encore synchronisé.} other{{count} repas ne sont pas encore synchronisés.}} Connectez-vous au réseau avant de vous déconnecter.",
  "logoutAnyway": "Se déconnecter quand même (repas perdus)",
```

`app_ar.arb`:

```json
  "unsyncedTitle": "وجبات لم تُزامَن بعد",
  "unsyncedBody": "{count, plural, =1{وجبة واحدة لم تُزامَن بعد.} other{{count} وجبات لم تُزامَن بعد.}} اتصل بالشبكة قبل تسجيل الخروج.",
  "logoutAnyway": "تسجيل الخروج رغم ذلك (ستضيع الوجبات)",
```

- [ ] **Step 3: Verify and commit**

Run the mobile command. Expected: no issues in `lib/`.

```bash
git add apps/mobile/lib/features/profile/presentation/profile_page.dart apps/mobile/lib/l10n
git commit -m "feat(mobile): logout asks before dropping unsynced offline meals

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Verification and hand-over

**Files:**
- Modify: `docs/superpowers/specs/2026-10-03-offline-serving-design.md` (status line only)

- [ ] **Step 1: Build, lint, analyze**

Run the backend build and lint command, then the mobile command. Expected: all clean. Don't run tests (user override).

- [ ] **Step 2: Mark the spec**

In the spec's header, change `- **Status:** Draft for review` to `- **Status:** Implemented (branch feat/offline-serving-2b, plan docs/superpowers/plans/2026-10-08-offline-serving-2b.md)`.

```bash
git add docs/superpowers/specs/2026-10-03-offline-serving-design.md
git commit -m "docs: mark Spec 2B implemented

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 3: Hand the field test to the user (do not run it)**

Spec §8 field test, before enabling `allowOfflineServing` for any region:
1. Use two phones, both in airplane mode, in a region with offline serving on.
2. Serve the same person on both phones.
3. Reconnect both.
4. Expected:
   - One phone shows "1 offline meal synced".
   - The other shows "1 serving to review", reading "Also served at … by …".
   - `GET /fastings/meals/review/:region` (admin) lists the conflict.
5. Undo an offline serve within 5 s, both before and after reconnecting. The meal must never stay recorded.
6. Set a phone's clock to two days ago and serve offline. Expected: "Check the phone's date and time" in the review list.
7. Log out with a meal pending. The guard must appear.
8. Enable a region with `PATCH /regions/:id` `{ name, active, allowOfflineServing: true }` as an admin.
