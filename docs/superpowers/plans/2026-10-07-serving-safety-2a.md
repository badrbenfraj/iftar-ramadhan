# Spec 2A: Serving Safety on a Bad Connection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a meal confirm safe on a slow or broken connection: idempotent confirms, a 5-second Undo (10 minutes on the server), "served by whom", an encrypted copy of the people list on the phone, and read-only identify with no network.

**Architecture:** The backend gets a `meal_events` table that becomes the record of every meal, with a partial unique index as the one-meal-per-day guarantee. Every write is mirrored into the old `fastings.takenMeals` / `lastTakenMeal` columns in the same transaction, so old apps and statistics keep working. The app sends a client-generated `clientEventId` with each confirm and reuses it on retry, so the server answers a retry with the original meal. The app also saves the region's list encrypted on disk and falls back to it when a lookup gets no answer.

**Tech Stack:** NestJS + TypeORM + PostgreSQL 16 (Jest unit and e2e); Flutter 3.44 / Dart 3.12, Riverpod 3, Dio 5, `flutter_secure_storage`, `path_provider`, plus one new package `cryptography` (AES-GCM).

**Spec:** [docs/superpowers/specs/2026-10-01-serving-safety-backend-design.md](../specs/2026-10-01-serving-safety-backend-design.md) (Spec 2A). Spec 2B ([2026-10-03-offline-serving-design.md](../specs/2026-10-03-offline-serving-design.md)) is **not** part of this plan.

## Global Constraints

- **Backward compatible:** a confirm with no `clientEventId` behaves as today. A 409 keeps `details.code = MEAL_ALREADY_TAKEN` and `details.lastTakenMeal`. `fastings.takenMeals` and `fastings.lastTakenMeal` are updated in the same transaction as every insert or revoke of an active meal event.
- **One active meal per person per day:** `UNIQUE (fastingId, serviceDay) WHERE revokedAt IS NULL AND conflict = false`. `serviceDay` is the local day in `APP_TIMEZONE` (default `Africa/Tunis`), computed by the server.
- **Undo windows:** 5 s on screen (`ScanTimings.undoWindow`). On the server, `UNDO_WINDOW_MINUTES` (default `10`) for the volunteer who served the meal, measured from `receivedAt`. Admins can undo any meal until the end of its service day.
- **Slow confirm:** "Sending… slow connection" after **2 s**, **one** automatic retry **3 s** after a network or timeout failure, and a `receiveTimeout` / `sendTimeout` of **15 s** for confirm and revoke. `connectTimeout` stays 10 s.
- **The Confirmed state appears only after the server's `200`.**
- **Revoked events are kept, never deleted.**
- **On-device list:** AES-GCM encrypted, with the key in `flutter_secure_storage`. It's wiped on logout and when the region changes.
- **New dependency:** `cryptography` only (mobile). No backend dependency.
- **Copy:** every new string goes in `app_en.arb`, `app_fr.arb` and `app_ar.arb`. Names go through `isolate()`; times and IDs go through `ltr()`. Digits are Western.
- **No PII in backend logs:** IDs only.
- **Before shipping (not before coding):** region access control (`docs/MIGRATION_REPORT.md` §6.6) must be enforced. This plan doesn't do it.

### Where the plan departs from the spec, and why
1. `meal_events.regionId` has **no foreign key**: `regions` has a composite primary key `(id, name)`, so `regions.id` alone can't be referenced.
2. Confirm **also** refuses when `fastings.lastTakenMeal` is today with no active event. This is a safety net for rows that no event covers.
3. **Not on this phone** offers **Retry** as well as **Scan again**, because a timeout is often just a slow network.
4. The spec's "Cancel" on a failed confirm is the existing **Skip** link.

## Review Focus

1. **A retry after the server already committed** (the response was lost) must end in **Confirmed with one meal**, never "Already served". It's pinned in Task 7 ("lost response, then retry").
2. **Undo of a meal recorded at registration** ("came today") must clear it from `takenMeals` like any other meal. **Undo must keep older days' meals.** Both are pinned in Task 4.
3. **A list saved yesterday** must not say "Already served" today, offline: the served flag expires with the day it was received. It's pinned in Task 10 (the `receivedAt` round trip) and Task 12 (yesterday's saved person → Unverified).
4. **A shared phone:** after logout, the next volunteer offline sees no saved list. It's pinned in Task 11.
5. **Legacy `takenMeals` strings that don't parse** must be skipped by the migration, not fail it. It's pinned in Task 1.

## How to run things (Windows host, no local Node/Flutter, Git Bash)

Start Docker Desktop first. The backend tests need PostgreSQL:

```bash
docker network create iftar-test 2>/dev/null || true
docker start iftar-test-db 2>/dev/null || docker run -d --name iftar-test-db --network iftar-test -e POSTGRES_USER=iftar -e POSTGRES_PASSWORD=iftar -e POSTGRES_DB=iftar_db postgres:16-alpine
```

Backend unit tests (`<pattern>` is a Jest path filter):

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W)/apps/backend:/app" -v iftar_backend_node_modules:/app/node_modules -w /app node:24-alpine sh -c "npm ci --no-audit --no-fund >/dev/null && npm test -- <pattern>"
```

Backend e2e tests:

```bash
MSYS_NO_PATHCONV=1 docker run --rm --network iftar-test -v "$(pwd -W)/apps/backend:/app" -v iftar_backend_node_modules:/app/node_modules -w /app -e DB_HOST=iftar-test-db -e DB_USER=iftar -e DB_PASS=iftar node:24-alpine sh -c "npm ci --no-audit --no-fund >/dev/null && npm run test:e2e -- <pattern>"
```

Backend lint: the same `docker run` with `npm run lint`.

Flutter (`<args>` is a test path, or `analyze`):

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/repo" -v iftar_pub_cache:/root/.pub-cache -w /repo/apps/mobile ghcr.io/cirruslabs/flutter:stable sh -c "flutter pub get >/dev/null && flutter gen-l10n && flutter test <args>"
```

For analysis, replace `flutter test <args>` with `flutter analyze`. Run all commands from the repository root. After the `npm ci` in the first run, later runs are quick, because `node_modules` lives in the `iftar_backend_node_modules` volume.

---

### Task 0: Branch and green baseline

**Files:** none.

- [ ] **Step 1: Create the branch**

```bash
git checkout main && git pull && git checkout -b feat/serving-safety-2a
```

- [ ] **Step 2: Confirm the suites are green before any change**

Run the backend unit tests (pattern `.`), the backend e2e tests (pattern `.`), and `flutter test` (no args). Expected: all PASS. If anything fails on `main`, stop and report it; don't build on a red baseline.

---

### Task 1: `meal_events` table, entity and backfill migration

**Files:**
- Create: `apps/backend/src/fasting/constants/error-codes.ts`
- Modify: `apps/backend/src/fasting/services/fasting.service.ts` (move the error codes out)
- Create: `apps/backend/src/fasting/entities/meal-event.entity.ts`
- Modify: `apps/backend/src/fasting/fasting.module.ts`
- Create: `apps/backend/migrations/1791200000000-CreateMealEvents.ts`
- Modify: `apps/backend/test/test-utils.ts`
- Test: `apps/backend/test/migrations/meal-events-migration.e2e-spec.ts`

**Interfaces:**
- Produces: `FASTING_ERROR_CODES` (in `src/fasting/constants/error-codes.ts`, re-exported from `fasting.service.ts`), with the new keys `CLIENT_EVENT_ID_REUSED`, `MEAL_EVENT_NOT_FOUND`, `UNDO_NOT_ALLOWED` and `UNDO_WINDOW_EXPIRED`. Entity `MealEvent` (table `meal_events`). Index name `UQ_meal_events_active_day`. Test helpers `connectionOptions` and `dbQuery(sql, params)`.

- [ ] **Step 1: Move the error codes to their own file**

Create `apps/backend/src/fasting/constants/error-codes.ts`:

```ts
/** Machine-readable error codes returned in `error.details.code`. */
export const FASTING_ERROR_CODES = {
  MEAL_ALREADY_TAKEN: 'MEAL_ALREADY_TAKEN',
  PERSON_ID_TAKEN: 'PERSON_ID_TAKEN',
  PERSON_NOT_FOUND: 'PERSON_NOT_FOUND',
  CLIENT_EVENT_ID_REUSED: 'CLIENT_EVENT_ID_REUSED',
  MEAL_EVENT_NOT_FOUND: 'MEAL_EVENT_NOT_FOUND',
  UNDO_NOT_ALLOWED: 'UNDO_NOT_ALLOWED',
  UNDO_WINDOW_EXPIRED: 'UNDO_WINDOW_EXPIRED',
} as const;
```

In `apps/backend/src/fasting/services/fasting.service.ts`, delete this block:

```ts
/** Machine-readable error codes returned in `error.details.code`. */
export const FASTING_ERROR_CODES = {
  MEAL_ALREADY_TAKEN: 'MEAL_ALREADY_TAKEN',
  PERSON_ID_TAKEN: 'PERSON_ID_TAKEN',
  PERSON_NOT_FOUND: 'PERSON_NOT_FOUND',
} as const;
```

Then add, after the last import:

```ts
import { FASTING_ERROR_CODES } from '../constants/error-codes';

export { FASTING_ERROR_CODES };
```

- [ ] **Step 2: Write the entity**

Create `apps/backend/src/fasting/entities/meal-event.entity.ts`:

```ts
import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryColumn,
} from 'typeorm';

import { User } from '../../user/entities/user.entity';
import { Fasting } from './fasting.entity';

export type MealEventSource = 'online' | 'offline' | 'backfill';

/**
 * One meal handed over, or the record of a second, conflicting hand-over
 * (`conflict = true`). The partial unique index is the database-level
 * guarantee of one active meal per person per day (spec 2A §3).
 * `fastings.takenMeals` / `lastTakenMeal` mirror the active events for
 * older clients and statistics (dual-write, spec 2A §3.3).
 */
@Entity('meal_events')
@Index('UQ_meal_events_active_day', ['fastingId', 'serviceDay'], {
  unique: true,
  where: '"revokedAt" IS NULL AND "conflict" = false',
})
@Index('IDX_meal_events_region_day', ['regionId', 'serviceDay'])
@Index('IDX_meal_events_fasting_served', ['fastingId', 'servedAt'])
export class MealEvent {
  /** The app's `clientEventId` when it sent one. */
  @PrimaryColumn({ type: 'uuid', default: () => 'gen_random_uuid()' })
  id: string;

  @Column()
  fastingId: number;

  @ManyToOne(() => Fasting, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'fastingId' })
  fasting?: Fasting;

  /**
   * Denormalized for region-scoped queries. No foreign key: `regions` has a
   * composite primary key (id, name).
   */
  @Column()
  regionId: number;

  /** Server time for online confirms. */
  @Column({ type: 'timestamptz' })
  servedAt: Date;

  /** Local day of `servedAt` in APP_TIMEZONE (YYYY-MM-DD). */
  @Column({ type: 'date' })
  serviceDay: string;

  @CreateDateColumn({ type: 'timestamptz' })
  receivedAt: Date;

  /** Null only for history backfilled from `fastings.takenMeals`. */
  @Column({ type: 'int', nullable: true })
  servedByUserId: number | null;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'servedByUserId' })
  servedBy?: User | null;

  @Column({ type: 'varchar', length: 16 })
  source: MealEventSource;

  @Column({ type: 'varchar', length: 64, nullable: true })
  deviceId: string | null;

  @Column({ default: false })
  conflict: boolean;

  /** Admin-review marker; unused until Spec 2B. */
  @Column({ type: 'varchar', nullable: true })
  flag: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  revokedAt: Date | null;

  @Column({ type: 'int', nullable: true })
  revokedByUserId: number | null;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'revokedByUserId' })
  revokedBy?: User | null;
}
```

In `apps/backend/src/fasting/fasting.module.ts`, import it and register it:

```ts
import { MealEvent } from './entities/meal-event.entity';
```

```ts
    TypeOrmModule.forFeature([Fasting, MealEvent]),
```

- [ ] **Step 3: Export the connection options and add a query helper**

In `apps/backend/test/test-utils.ts`, change `const connectionOptions = {` to `export const connectionOptions = {`, and add at the end of the file:

```ts
/** Raw SQL against the e2e database (set up by createDBEntities). */
export const dbQuery = <T = any>(
  sql: string,
  params: unknown[] = [],
): Promise<T[]> => entitiesDataSource.query(sql, params);
```

- [ ] **Step 4: Write the failing migration test**

Create `apps/backend/test/migrations/meal-events-migration.e2e-spec.ts`:

```ts
import { DataSource } from 'typeorm';

import { InitialSchema1740317360063 } from '../../migrations/1740317360063-InitialSchema';
import { AddCinToFastingPerson1740815824821 } from '../../migrations/1740815824821-AddCinToFastingPerson';
import { MakeLastTakenMealNullable1790850000000 } from '../../migrations/1790850000000-MakeLastTakenMealNullable';
import { CreateMealEvents1791200000000 } from '../../migrations/1791200000000-CreateMealEvents';
import {
  connectionOptions,
  resetDBBeforeTest,
  TEST_DB_NAME,
} from '../test-utils';

const before = [
  InitialSchema1740317360063,
  AddCinToFastingPerson1740815824821,
  MakeLastTakenMealNullable1790850000000,
];

const open = async (migrations: Function[]): Promise<DataSource> => {
  const ds = new DataSource({
    ...connectionOptions,
    database: TEST_DB_NAME,
    migrations,
  });
  await ds.initialize();
  return ds;
};

describe('CreateMealEvents migration (e2e)', () => {
  let ds: DataSource;

  beforeAll(async () => {
    await resetDBBeforeTest();
    const old = await open(before);
    await old.runMigrations();
    const [user] = await old.query(
      `INSERT INTO "users" ("name","password","username","roles","isAccountDisabled","email")
       VALUES ('Vol','x','vol','USER',false,'vol@example.com') RETURNING "id"`,
    );
    const [region] = await old.query(
      `INSERT INTO "regions" ("name","active") VALUES ('Dar Sokra', true) RETURNING "id"`,
    );
    const insert = (id: number, last: string | null, taken: string[]) =>
      old.query(
        `INSERT INTO "fastings" ("id","firstName","lastName","familyMeal","singleMeal",
           "lastTakenMeal","takenMeals","regionId","regionName","createdById")
         VALUES ($1,'A','B',1,1,$2,$3,$4,'Dar Sokra',$5)`,
        [id, last, taken, region.id, user.id],
      );
    await insert(1, '2025-03-03T18:00:00Z', [
      '2025-03-02T18:00:00.000Z',
      '2025-03-03T18:00:00.000Z',
    ]);
    // Two meals on one Tunis day, plus an entry no date parser can read.
    await insert(2, '2025-03-03T19:00:00Z', [
      '2025-03-03T17:00:00.000Z',
      '2025-03-03T19:00:00.000Z',
      'not a date',
    ]);
    await insert(3, null, []);
    // 23:30 UTC on Mar 2 is 00:30 on Mar 3 in Tunis.
    await insert(4, '2025-03-02T23:30:00Z', ['2025-03-02T23:30:00.000Z']);
    await old.destroy();

    ds = await open([...before, CreateMealEvents1791200000000]);
    await ds.runMigrations();
  });

  afterAll(async () => {
    await ds?.destroy();
  });

  it('backfills one event per readable meal, by Tunis day, with duplicates as conflicts', async () => {
    const rows = await ds.query(
      `SELECT "fastingId", "serviceDay"::text AS "day", "conflict", "source", "servedByUserId"
       FROM "meal_events" ORDER BY "fastingId", "servedAt"`,
    );
    const base = { source: 'backfill', servedByUserId: null };
    expect(rows).toEqual([
      { ...base, fastingId: 1, day: '2025-03-02', conflict: false },
      { ...base, fastingId: 1, day: '2025-03-03', conflict: false },
      { ...base, fastingId: 2, day: '2025-03-03', conflict: false },
      { ...base, fastingId: 2, day: '2025-03-03', conflict: true },
      { ...base, fastingId: 4, day: '2025-03-03', conflict: false },
    ]);
  });

  it('refuses a second active meal for a person and day, but stores a conflict record', async () => {
    const insert = (conflict: boolean) =>
      ds.query(
        `INSERT INTO "meal_events" ("fastingId","regionId","servedAt","serviceDay","source","conflict")
         SELECT 1, "regionId", now(), '2025-03-03', 'online', $1 FROM "fastings" WHERE "id" = 1`,
        [conflict],
      );
    await expect(insert(false)).rejects.toThrow(/duplicate key/);
    await expect(insert(true)).resolves.toBeDefined();
  });

  it('down() drops the table and leaves the meal history of fastings intact', async () => {
    await ds.undoLastMigration();
    const [{ exists }] = await ds.query(
      `SELECT to_regclass('meal_events') IS NOT NULL AS "exists"`,
    );
    expect(exists).toBe(false);
    const rows = await ds.query(
      `SELECT "takenMeals" FROM "fastings" ORDER BY "id"`,
    );
    expect(rows.map((r) => r.takenMeals.length)).toEqual([2, 3, 0, 1]);
  });
});
```

- [ ] **Step 5: Run it to see it fail**

Run the backend e2e tests with pattern `meal-events-migration`. Expected: FAIL. The module `../../migrations/1791200000000-CreateMealEvents` can't be found.

- [ ] **Step 6: Write the migration**

Create `apps/backend/migrations/1791200000000-CreateMealEvents.ts`:

```ts
import { randomUUID } from 'crypto';
import { MigrationInterface, QueryRunner } from 'typeorm';

import {
  DEFAULT_APP_TIMEZONE,
  localDayKey,
} from '../src/shared/utils/local-day';

/**
 * Spec 2A §3: one row per meal handed over. Backfills one event per readable
 * entry in fastings.takenMeals; a second entry on the same local day becomes
 * a conflict record. fastings is not modified, so down() is lossless.
 */
export class CreateMealEvents1791200000000 implements MigrationInterface {
  name = 'CreateMealEvents1791200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`CREATE TABLE "meal_events" (
      "id" uuid NOT NULL DEFAULT gen_random_uuid(),
      "fastingId" integer NOT NULL,
      "regionId" integer NOT NULL,
      "servedAt" TIMESTAMP WITH TIME ZONE NOT NULL,
      "serviceDay" date NOT NULL,
      "receivedAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
      "servedByUserId" integer,
      "source" character varying(16) NOT NULL,
      "deviceId" character varying(64),
      "conflict" boolean NOT NULL DEFAULT false,
      "flag" character varying,
      "revokedAt" TIMESTAMP WITH TIME ZONE,
      "revokedByUserId" integer,
      CONSTRAINT "PK_meal_events" PRIMARY KEY ("id"),
      CONSTRAINT "FK_meal_events_fasting" FOREIGN KEY ("fastingId") REFERENCES "fastings"("id") ON DELETE CASCADE,
      CONSTRAINT "FK_meal_events_served_by" FOREIGN KEY ("servedByUserId") REFERENCES "users"("id"),
      CONSTRAINT "FK_meal_events_revoked_by" FOREIGN KEY ("revokedByUserId") REFERENCES "users"("id")
    )`);
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_meal_events_active_day" ON "meal_events" ("fastingId", "serviceDay") WHERE "revokedAt" IS NULL AND "conflict" = false`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_meal_events_region_day" ON "meal_events" ("regionId", "serviceDay")`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_meal_events_fasting_served" ON "meal_events" ("fastingId", "servedAt")`,
    );
    await this.backfill(queryRunner);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE "meal_events"`);
  }

  private async backfill(queryRunner: QueryRunner): Promise<void> {
    const timeZone = process.env.APP_TIMEZONE || DEFAULT_APP_TIMEZONE;
    const rows: Array<{
      id: number;
      regionId: number | null;
      takenMeals: string[];
    }> = await queryRunner.query(
      `SELECT "id", "regionId", "takenMeals" FROM "fastings" WHERE cardinality("takenMeals") > 0`,
    );
    let skipped = 0;
    for (const row of rows) {
      if (row.regionId == null) {
        skipped += row.takenMeals.length;
        continue;
      }
      const meals = row.takenMeals
        .map((raw) => new Date(raw))
        .filter((date) => {
          const readable = !isNaN(date.getTime());
          if (!readable) skipped++;
          return readable;
        })
        .sort((a, b) => a.getTime() - b.getTime());
      const days = new Set<string>();
      for (const servedAt of meals) {
        const day = localDayKey(servedAt, timeZone);
        const conflict = days.has(day);
        days.add(day);
        await queryRunner.query(
          `INSERT INTO "meal_events" ("id","fastingId","regionId","servedAt","serviceDay","receivedAt","source","conflict")
           VALUES ($1,$2,$3,$4,$5,$4,'backfill',$6)`,
          [randomUUID(), row.id, row.regionId, servedAt, day, conflict],
        );
      }
    }
    if (skipped > 0) {
      // Counts only: no personal data in logs.
      console.warn(
        `CreateMealEvents: ${skipped} takenMeals entries were not backfilled (unreadable date or no region)`,
      );
    }
  }
}
```

- [ ] **Step 7: Run the migration test, then the existing e2e suite**

Run the backend e2e tests with pattern `meal-events-migration`. Expected: PASS (3 tests).

Then run the backend e2e tests with pattern `.`. Expected: PASS, which proves the new entity syncs cleanly into the e2e schema. Then run the backend unit tests with pattern `.`. Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add apps/backend/src/fasting apps/backend/migrations/1791200000000-CreateMealEvents.ts apps/backend/test
git commit -m "feat(backend): meal_events table with backfill and one-active-meal-per-day index

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Idempotent confirm, recorded as a meal event

**Files:**
- Create: `apps/backend/src/fasting/dtos/meal-event-output.dto.ts`
- Create: `apps/backend/src/fasting/services/meal-event.service.ts`
- Create: `apps/backend/src/fasting/services/meal-event.service.spec.ts`
- Modify: `apps/backend/src/fasting/dtos/fasting-input.dto.ts` (`ConfirmMealInput`)
- Modify: `apps/backend/src/fasting/dtos/fasting-output.dto.ts`
- Modify: `apps/backend/src/fasting/services/fasting.service.ts`
- Modify: `apps/backend/src/fasting/services/fasting.service.spec.ts`
- Modify: `apps/backend/src/fasting/fasting.module.ts`
- Test: `apps/backend/test/fasting/meal-events.e2e-spec.ts`

**Interfaces:**
- Consumes: `MealEvent`, `FASTING_ERROR_CODES` and `dbQuery` (Task 1).
- Produces:
  - `MealEventOutput { eventId: string; servedAt: string; servedBy: { id: number; name: string } | null; revokedAt: string | null }`.
  - `MealEventService.confirm(ctx, fastingId, region, input): Promise<MealEventOutput>`, plus `serviceDay(at: Date): string`, `findEvent(manager, id)` and `activeEventOn(manager, fastingId, day)`, which return `MealEventRow | null`.
  - `insertActive(manager, { id, fastingId, regionId, servedAt, servedByUserId, deviceId }): Promise<string>`.
  - `toMealEventOutput(row)`.
  - `FastingOutput` gains the optional `meal`, `todayMeal` and `meals`.
  - `FastingService.toOutput(fasting, extras?)`.
  - The confirm body accepts `clientEventId` (uuid v4) and `deviceId` (≤ 64 characters).

- [ ] **Step 1: Write the failing e2e tests**

Create `apps/backend/test/fasting/meal-events.e2e-spec.ts`. Tasks 3 and 4 add more `describe` blocks to this file. They go inside the outer `describe`, before `afterAll`.

```ts
import { HttpStatus, INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { randomUUID } from 'crypto';
import request from 'supertest';

import { AppModule } from '../../src/app.module';
import { VALIDATION_PIPE_OPTIONS } from '../../src/shared/constants';
import {
  closeDBAfterTest,
  createDBEntities,
  dbQuery,
  resetDBBeforeTest,
  seedAdminUser,
  seedRegion,
} from '../test-utils';

/** Spec 2A: meal events, idempotent confirm, served-by and undo. */
describe('Meal events (e2e)', () => {
  let app: INestApplication;
  let regionId: number;
  let volunteer: string;
  let other: string;
  let admin: string;

  const server = () => app.getHttpServer();
  const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

  const signUp = async (username: string, name: string): Promise<string> => {
    await request(server())
      .post('/auth/register')
      .send({
        name,
        username,
        email: `${username}@example.com`,
        password: `${username}-pass`,
        region: { id: regionId },
      })
      .expect(HttpStatus.CREATED);
    const login = await request(server())
      .post('/auth/login')
      .send({ username, password: `${username}-pass` })
      .expect(HttpStatus.OK);
    return login.body.data.accessToken;
  };

  const createPerson = (id: number, extra: Record<string, unknown> = {}) =>
    request(server())
      .post('/fastings')
      .set(bearer(volunteer))
      .send({
        id,
        firstName: 'Najwa',
        lastName: 'Chalbi',
        singleMeal: 1,
        familyMeal: 1,
        region: regionId,
        cameToday: false,
        ...extra,
      })
      .expect(HttpStatus.CREATED);

  const confirm = (
    id: number,
    body: Record<string, unknown> = {},
    token = volunteer,
  ) =>
    request(server())
      .patch(`/fastings/confirm/${regionId}/${id}`)
      .set(bearer(token))
      .send(body);

  const revoke = (eventId: string, token = volunteer) =>
    request(server())
      .post(`/fastings/meals/${eventId}/revoke`)
      .set(bearer(token))
      .send();

  const activeMeals = async (fastingId: number): Promise<number> => {
    const [row] = await dbQuery<{ n: string }>(
      `SELECT count(*) AS "n" FROM "meal_events"
       WHERE "fastingId" = $1 AND "revokedAt" IS NULL AND "conflict" = false`,
      [fastingId],
    );
    return Number(row.n);
  };

  beforeAll(async () => {
    await resetDBBeforeTest();
    await createDBEntities();
    regionId = (await seedRegion()).id;
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe(VALIDATION_PIPE_OPTIONS));
    await app.init();
    volunteer = await signUp('volunteer', 'Volunteer');
    other = await signUp('other', 'Other Volunteer');
    admin = (await seedAdminUser(app)).authTokenForAdmin.accessToken;
  });

  describe('confirm', () => {
    it('answers a retry of the same clientEventId with the same meal, recorded once', async () => {
      await createPerson(101);
      const clientEventId = randomUUID();
      const first = await confirm(101, { clientEventId }).expect(HttpStatus.OK);
      const retry = await confirm(101, { clientEventId }).expect(HttpStatus.OK);

      expect(first.body.data.meal.eventId).toBe(clientEventId);
      expect(retry.body.data.meal.eventId).toBe(clientEventId);
      expect(first.body.data.meal.servedBy).toEqual({
        id: expect.any(Number),
        name: 'Volunteer',
      });
      expect(retry.body.data.takenMeals).toHaveLength(1);
      expect(await activeMeals(101)).toBe(1);
    });

    it('rejects a clientEventId already used for another person', async () => {
      await createPerson(102);
      await createPerson(103);
      const clientEventId = randomUUID();
      await confirm(102, { clientEventId }).expect(HttpStatus.OK);
      const res = await confirm(103, { clientEventId }).expect(
        HttpStatus.UNPROCESSABLE_ENTITY,
      );
      expect(res.body.error.details.code).toBe('CLIENT_EVENT_ID_REUSED');
      expect(await activeMeals(103)).toBe(0);
    });

    it('says when and by whom on a second meal, and keeps the legacy field', async () => {
      await createPerson(104);
      await confirm(104, { clientEventId: randomUUID() }).expect(HttpStatus.OK);
      const res = await confirm(104, { clientEventId: randomUUID() }, other).expect(
        HttpStatus.CONFLICT,
      );
      const details = res.body.error.details;
      expect(details.code).toBe('MEAL_ALREADY_TAKEN');
      expect(details.servedBy.name).toBe('Volunteer');
      expect(typeof details.servedAt).toBe('string');
      expect(details.lastTakenMeal).toBe(details.servedAt);
    });

    it('lets exactly one of many concurrent confirms with different IDs win', async () => {
      await createPerson(105);
      const statuses = await Promise.all(
        Array.from({ length: 10 }, () =>
          confirm(105, { clientEventId: randomUUID() }).then((r) => r.status),
        ),
      );
      expect(statuses.filter((s) => s === HttpStatus.OK)).toHaveLength(1);
      expect(statuses.filter((s) => s === HttpStatus.CONFLICT)).toHaveLength(9);
      expect(await activeMeals(105)).toBe(1);
    });

    it('answers concurrent retries of one clientEventId with the same meal', async () => {
      await createPerson(106);
      const clientEventId = randomUUID();
      const responses = await Promise.all(
        Array.from({ length: 5 }, () => confirm(106, { clientEventId })),
      );
      expect(responses.map((r) => r.status)).toEqual(Array(5).fill(HttpStatus.OK));
      expect(new Set(responses.map((r) => r.body.data.meal.eventId))).toEqual(
        new Set([clientEventId]),
      );
      expect(await activeMeals(106)).toBe(1);
    });

    it('stores the device ID sent with the confirm', async () => {
      await createPerson(107);
      const clientEventId = randomUUID();
      await confirm(107, { clientEventId, deviceId: 'inst-test' }).expect(HttpStatus.OK);
      const [row] = await dbQuery(
        `SELECT "deviceId", "source" FROM "meal_events" WHERE "id" = $1`,
        [clientEventId],
      );
      expect(row).toEqual({ deviceId: 'inst-test', source: 'online' });
    });

    it('rejects a malformed clientEventId', async () => {
      await createPerson(108);
      await confirm(108, { clientEventId: 'not-a-uuid' }).expect(HttpStatus.BAD_REQUEST);
    });
  });

  afterAll(async () => {
    await app.close();
    await closeDBAfterTest();
  });
});
```

`other` and `admin` are first used in Tasks 2 and 4. `revoke` is used in Task 4. Keep them now so that later tasks only add `describe` blocks. Lint may warn about the unused `revoke` until Task 4; that's fine.

- [ ] **Step 2: Run them to see them fail**

Run the backend e2e tests with pattern `meal-events.e2e`. Expected: FAIL. `body.data.meal` is undefined, and the malformed ID gets a 200 instead of a 400.

- [ ] **Step 3: Add the output DTO**

Create `apps/backend/src/fasting/dtos/meal-event-output.dto.ts`:

```ts
import { ApiProperty } from '@nestjs/swagger';
import { Expose } from 'class-transformer';

export class MealServedByOutput {
  @Expose()
  @ApiProperty()
  id: number;

  @Expose()
  @ApiProperty()
  name: string;
}

/** One meal as the apps see it (spec 2A §4). */
export class MealEventOutput {
  @Expose()
  @ApiProperty({ format: 'uuid' })
  eventId: string;

  @Expose()
  @ApiProperty({ description: 'ISO instant' })
  servedAt: string;

  @Expose()
  @ApiProperty({
    type: MealServedByOutput,
    nullable: true,
    description: 'Null for history recorded before served-by existed',
  })
  servedBy: MealServedByOutput | null;

  @Expose()
  @ApiProperty({ nullable: true, description: 'ISO instant, set once undone' })
  revokedAt: string | null;
}
```

In `apps/backend/src/fasting/dtos/fasting-output.dto.ts`, add the import `import { MealEventOutput } from './meal-event-output.dto';` and these fields before `createdAt`:

```ts
  @Expose()
  @ApiProperty({
    type: MealEventOutput,
    required: false,
    description: 'Confirm only: the meal this request recorded (or replayed)',
  })
  meal?: MealEventOutput;

  @Expose()
  @ApiProperty({
    type: MealEventOutput,
    required: false,
    nullable: true,
    description: "Tonight's active meal, if any",
  })
  todayMeal?: MealEventOutput | null;

  @Expose()
  @ApiProperty({
    type: [MealEventOutput],
    required: false,
    description: 'Single-person read only: every meal, newest first',
  })
  meals?: MealEventOutput[];
```

- [ ] **Step 4: Accept `clientEventId` and `deviceId` on confirm**

In `apps/backend/src/fasting/dtos/fasting-input.dto.ts`, add `IsUUID` and `MaxLength` to the `class-validator` import. Then add to `ConfirmMealInput`, after `comment`:

```ts
  /**
   * Generated by the app per confirm and reused on every retry of it, so a
   * retry can never record a second meal (spec 2A §4.1).
   */
  @IsUUID('4')
  @IsOptional()
  @ApiProperty({ required: false, format: 'uuid' })
  clientEventId?: string;

  /** Installation ID of the phone, for the audit trail. */
  @IsString()
  @MaxLength(64)
  @IsOptional()
  @ApiProperty({ required: false, maxLength: 64 })
  deviceId?: string;
```

- [ ] **Step 5: Write `MealEventService`**

Create `apps/backend/src/fasting/services/meal-event.service.ts`:

```ts
import {
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DataSource, EntityManager } from 'typeorm';

import { Action } from '../../shared/acl/action.constant';
import { Actor } from '../../shared/acl/actor.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import {
  DEFAULT_APP_TIMEZONE,
  isSameLocalDay,
  localDayKey,
} from '../../shared/utils/local-day';
import { FASTING_ERROR_CODES } from '../constants/error-codes';
import { ConfirmMealInput } from '../dtos/fasting-input.dto';
import { MealEventOutput } from '../dtos/meal-event-output.dto';
import { Fasting } from '../entities/fasting.entity';
import { FastingAclService } from './fasting-acl.service';

/** A meal event row joined with the serving volunteer's name. */
export interface MealEventRow {
  eventId: string;
  fastingId: number;
  regionId: number;
  servedAt: Date;
  receivedAt: Date;
  /** YYYY-MM-DD (selected as text: the pg driver would turn a date into a local-midnight Date). */
  serviceDay: string;
  servedByUserId: number | null;
  servedByName: string | null;
  conflict: boolean;
  revokedAt: Date | null;
}

const EVENT_SELECT = `SELECT e."id" AS "eventId", e."fastingId", e."regionId",
  e."servedAt", e."receivedAt", e."serviceDay"::text AS "serviceDay",
  e."servedByUserId", u."name" AS "servedByName", e."conflict", e."revokedAt"
  FROM "meal_events" e LEFT JOIN "users" u ON u."id" = e."servedByUserId"`;

export function toMealEventOutput(row: MealEventRow): MealEventOutput {
  return {
    eventId: row.eventId,
    servedAt: new Date(row.servedAt).toISOString(),
    servedBy:
      row.servedByUserId == null
        ? null
        : { id: row.servedByUserId, name: row.servedByName ?? '' },
    revokedAt: row.revokedAt ? new Date(row.revokedAt).toISOString() : null,
  };
}

/**
 * Meals handed over (spec 2A). `meal_events` is the record; every insert or
 * revoke of an active event is mirrored into `fastings.takenMeals` /
 * `lastTakenMeal` in the same transaction (dual-write, §3.3). The
 * `SELECT … FOR UPDATE` on the person's `fastings` row serializes all writes
 * for that person.
 */
@Injectable()
export class MealEventService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly aclService: FastingAclService,
    private readonly configService: ConfigService,
    private readonly logger: AppLogger,
  ) {
    this.logger.setContext(MealEventService.name);
  }

  private get timeZone(): string {
    return this.configService.get<string>('timezone') || DEFAULT_APP_TIMEZONE;
  }

  /** The distribution day (APP_TIMEZONE) an instant belongs to. */
  serviceDay(at: Date): string {
    return localDayKey(at, this.timeZone);
  }

  /**
   * Records tonight's meal. With a `clientEventId` already stored for this
   * person, returns that meal instead (a retry). A second meal the same day
   * fails with 409 MEAL_ALREADY_TAKEN, saying when and by whom.
   */
  async confirm(
    ctx: RequestContext,
    fastingId: number,
    region: number,
    input: ConfirmMealInput,
  ): Promise<MealEventOutput> {
    this.logger.log(ctx, `${this.confirm.name} was called`);

    if (!Number.isInteger(fastingId) || !Number.isInteger(region)) {
      throw new NotFoundException({
        message: 'Fasting ID and Region ID are required',
        code: FASTING_ERROR_CODES.PERSON_NOT_FOUND,
      });
    }

    const actor: Actor = ctx.user;

    return this.dataSource.transaction(async (manager) => {
      const rows: Array<{ id: number; lastTakenMeal: Date | null }> =
        await manager.query(
          `SELECT "id", "lastTakenMeal" FROM "fastings"
           WHERE "id" = $1 AND "regionId" = $2
           FOR UPDATE`,
          [fastingId, region],
        );
      if (rows.length === 0) {
        throw new NotFoundException({
          message: `Fasting record with ID ${fastingId} not found in region ${region}`,
          code: FASTING_ERROR_CODES.PERSON_NOT_FOUND,
        });
      }

      const fasting = await manager.findOne(Fasting, {
        where: { id: fastingId },
      });
      const isAllowed = this.aclService
        .forActor(actor)
        .canDoAction(Action.Update, fasting);
      if (!isAllowed) {
        throw new UnauthorizedException();
      }

      if (input.clientEventId) {
        const existing = await this.findEvent(manager, input.clientEventId);
        if (existing) {
          if (existing.fastingId !== fastingId) {
            throw new UnprocessableEntityException({
              message: 'This clientEventId was already used for another person',
              code: FASTING_ERROR_CODES.CLIENT_EVENT_ID_REUSED,
            });
          }
          return toMealEventOutput(existing);
        }
      }

      const now = new Date();
      const active = await this.activeEventOn(
        manager,
        fastingId,
        this.serviceDay(now),
      );
      const lastTakenMeal = rows[0].lastTakenMeal
        ? new Date(rows[0].lastTakenMeal)
        : null;
      // The event is the record. The lastTakenMeal check is a safety net for
      // a meal written without an event (none should exist after the backfill).
      if (active || isSameLocalDay(lastTakenMeal, now, this.timeZone)) {
        const meal = active ? toMealEventOutput(active) : null;
        const servedAt = meal?.servedAt ?? lastTakenMeal.toISOString();
        throw new ConflictException({
          message: 'Meal already collected today',
          code: FASTING_ERROR_CODES.MEAL_ALREADY_TAKEN,
          // Read by older apps.
          lastTakenMeal: servedAt,
          servedAt,
          servedBy: meal?.servedBy ?? null,
        });
      }

      const eventId = await this.insertActive(manager, {
        id: input.clientEventId ?? null,
        fastingId,
        regionId: region,
        servedAt: now,
        servedByUserId: actor.id,
        deviceId: input.deviceId ?? null,
      });

      const phone = input.phone === undefined ? null : input.phone;
      const comment = input.comment === undefined ? null : input.comment;
      await manager.query(
        `UPDATE "fastings"
         SET "lastTakenMeal" = $3,
             "takenMeals" = array_append("takenMeals", $4::varchar),
             "phone" = CASE WHEN $5::boolean THEN $6::varchar ELSE "phone" END,
             "comment" = CASE WHEN $7::boolean THEN $8::text ELSE "comment" END,
             "updatedAt" = now()
         WHERE "id" = $1 AND "regionId" = $2`,
        [
          fastingId,
          region,
          now,
          now.toISOString(),
          input.phone !== undefined,
          phone,
          input.comment !== undefined,
          comment,
        ],
      );

      return toMealEventOutput(await this.findEvent(manager, eventId));
    });
  }

  /** Inserts an active online event and returns its ID. Does not dual-write. */
  async insertActive(
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
    const [row] = await manager.query(
      `INSERT INTO "meal_events"
         ("id","fastingId","regionId","servedAt","serviceDay","servedByUserId","source","deviceId")
       VALUES (COALESCE($1::uuid, gen_random_uuid()), $2, $3, $4, $5, $6, 'online', $7)
       RETURNING "id"`,
      [
        event.id,
        event.fastingId,
        event.regionId,
        event.servedAt,
        this.serviceDay(event.servedAt),
        event.servedByUserId,
        event.deviceId,
      ],
    );
    return row.id;
  }

  async findEvent(
    manager: EntityManager,
    id: string,
  ): Promise<MealEventRow | null> {
    const rows = await manager.query(`${EVENT_SELECT} WHERE e."id" = $1`, [id]);
    return rows[0] ?? null;
  }

  async activeEventOn(
    manager: EntityManager,
    fastingId: number,
    serviceDay: string,
  ): Promise<MealEventRow | null> {
    const rows = await manager.query(
      `${EVENT_SELECT}
       WHERE e."fastingId" = $1 AND e."serviceDay" = $2
         AND e."revokedAt" IS NULL AND e."conflict" = false`,
      [fastingId, serviceDay],
    );
    return rows[0] ?? null;
  }
}
```

In `apps/backend/src/fasting/fasting.module.ts`, import `MealEventService` from `./services/meal-event.service` and add it to `providers`.

- [ ] **Step 6: Delegate the confirm from `FastingService`**

In `apps/backend/src/fasting/services/fasting.service.ts`:

1. Add these imports:

```ts
import { MealEventOutput } from '../dtos/meal-event-output.dto';
import { MealEventService } from './meal-event.service';
```

2. Add `private meals: MealEventService,` to the constructor, after `private aclService: FastingAclService,`.

3. Replace `toOutput` with:

```ts
  /**
   * Builds the API representation of a person. `createdBy` is dropped on
   * purpose: it is an eager relation that would otherwise leak the creator's
   * user record (including the password hash) to every client.
   */
  private toOutput(
    fasting: Fasting,
    extras: {
      meal?: MealEventOutput;
      todayMeal?: MealEventOutput | null;
      meals?: MealEventOutput[];
    } = {},
  ): FastingOutput {
    const { createdBy, ...rest } = fasting;
    return plainToClass(FastingOutput, {
      ...rest,
      mealTakenToday: isSameLocalDay(
        fasting.lastTakenMeal ? new Date(fasting.lastTakenMeal) : null,
        new Date(),
        this.timeZone,
      ),
      ...extras,
    });
  }
```

4. Replace the whole `confirmMeal` method (doc comment included) with:

```ts
  /**
   * Records today's meal (spec 2A §4.1); see MealEventService.confirm for the
   * one-meal-per-day and retry rules.
   */
  async confirmMeal(
    ctx: RequestContext,
    fastingId: number,
    region: number,
    input: ConfirmMealInput,
  ): Promise<FastingOutput> {
    this.logger.log(ctx, `${this.confirmMeal.name} was called`);

    const meal = await this.meals.confirm(ctx, fastingId, region, input);
    const saved = await this.repository.getByIdAndRegion(fastingId, region);
    return this.toOutput(saved, {
      meal,
      todayMeal: meal.revokedAt ? null : meal,
    });
  }
```

5. Remove the imports that are now unused (`ConflictException`, `NotFoundException`), but only if lint reports them as unused.

- [ ] **Step 7: Update the `FastingService` unit tests**

In `apps/backend/src/fasting/services/fasting.service.spec.ts`:

1. Add `import { MealEventService } from './meal-event.service';`.
2. After `const logger = …`, add:

```ts
  const meals = {
    confirm: jest.fn(),
    todayMealsByRegion: jest.fn(async () => new Map()),
    todayMealOf: jest.fn(async () => null),
    mealsOf: jest.fn(async () => []),
    recordRegistrationMeal: jest.fn(),
    revoke: jest.fn(),
  };
```

3. Add `{ provide: MealEventService, useValue: meals },` to the testing module's `providers`.
4. Replace the whole `describe('confirmMeal', …)` block with:

```ts
  describe('confirmMeal', () => {
    it('returns the person with the meal the request recorded', async () => {
      const meal = {
        eventId: '6f1c2c55-7a8e-4d39-9b0e-6c7c1f0a9d11',
        servedAt: new Date().toISOString(),
        servedBy: { id: 7, name: 'Vol' },
        revokedAt: null,
      };
      meals.confirm.mockResolvedValue(meal);
      repository.getByIdAndRegion.mockResolvedValue({
        ...person,
        lastTakenMeal: new Date(),
      });

      const result = await service.confirmMeal(ctx, 42, 1, { phone: '123' });

      expect(meals.confirm).toHaveBeenCalledWith(ctx, 42, 1, { phone: '123' });
      expect(result.meal).toEqual(meal);
      expect(result.todayMeal).toEqual(meal);
      expect(result.mealTakenToday).toBe(true);
      expect(result).not.toHaveProperty('createdBy');
    });

    it('has no meal tonight when the replayed meal was undone', async () => {
      meals.confirm.mockResolvedValue({
        eventId: '6f1c2c55-7a8e-4d39-9b0e-6c7c1f0a9d11',
        servedAt: new Date().toISOString(),
        servedBy: { id: 7, name: 'Vol' },
        revokedAt: new Date().toISOString(),
      });
      repository.getByIdAndRegion.mockResolvedValue({
        ...person,
        lastTakenMeal: null,
      });

      const result = await service.confirmMeal(ctx, 42, 1, {});

      expect(result.todayMeal).toBeNull();
      expect(result.mealTakenToday).toBe(false);
    });
  });
```

5. Remove `NotFoundException` from the `@nestjs/common` import if it's now unused.

- [ ] **Step 8: Unit-test the cheap rejection in `MealEventService`**

Create `apps/backend/src/fasting/services/meal-event.service.spec.ts`:

```ts
import { NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { DataSource } from 'typeorm';

import { ROLE } from '../../auth/constants/role.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { FastingAclService } from './fasting-acl.service';
import { MealEventService, toMealEventOutput } from './meal-event.service';

describe('MealEventService', () => {
  let service: MealEventService;
  const dataSource = { transaction: jest.fn() };
  const ctx = new RequestContext();
  ctx.user = { id: 7, username: 'vol', roles: [ROLE.USER] };

  beforeEach(async () => {
    jest.clearAllMocks();
    const moduleRef = await Test.createTestingModule({
      providers: [
        MealEventService,
        FastingAclService,
        { provide: DataSource, useValue: dataSource },
        { provide: ConfigService, useValue: { get: jest.fn(() => 'Africa/Tunis') } },
        { provide: AppLogger, useValue: { setContext: jest.fn(), log: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(MealEventService);
  });

  it('returns 404 for a non-numeric id (invalid QR) without opening a transaction', async () => {
    await expect(
      service.confirm(ctx, Number('abc'), 1, {}),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it('computes the service day in APP_TIMEZONE across midnight', () => {
    // 22:59 UTC = 23:59 Tunis; 23:01 UTC = 00:01 the next day in Tunis.
    expect(service.serviceDay(new Date('2027-02-21T22:59:00Z'))).toBe('2027-02-21');
    expect(service.serviceDay(new Date('2027-02-21T23:01:00Z'))).toBe('2027-02-22');
  });

  it('maps a row to the API shape, with no volunteer for backfilled history', () => {
    const base = {
      eventId: 'e',
      fastingId: 1,
      regionId: 1,
      servedAt: new Date('2027-02-21T17:44:10Z'),
      receivedAt: new Date('2027-02-21T17:44:10Z'),
      serviceDay: '2027-02-21',
      conflict: false,
      revokedAt: null,
    };
    expect(
      toMealEventOutput({ ...base, servedByUserId: 3, servedByName: 'Sami' }),
    ).toEqual({
      eventId: 'e',
      servedAt: '2027-02-21T17:44:10.000Z',
      servedBy: { id: 3, name: 'Sami' },
      revokedAt: null,
    });
    expect(
      toMealEventOutput({ ...base, servedByUserId: null, servedByName: null })
        .servedBy,
    ).toBeNull();
  });
});
```

- [ ] **Step 9: Run the tests**

Run the backend unit tests with pattern `fasting`. Expected: PASS. Then run the backend e2e tests with pattern `.`. Expected: PASS for both `confirm-meal` and `meal-events`. `confirm-meal` still passes because its "came today" person is refused through the `lastTakenMeal` safety net until Task 3 records an event at registration.

- [ ] **Step 10: Commit**

```bash
git add apps/backend
git commit -m "feat(backend): idempotent confirm with clientEventId, recorded as a meal event; 409 says by whom

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Tonight's meal and meal history in reads; registration records an event

**Files:**
- Modify: `apps/backend/src/fasting/services/meal-event.service.ts`
- Modify: `apps/backend/src/fasting/services/fasting.service.ts`
- Modify: `apps/backend/src/fasting/services/fasting.service.spec.ts`
- Test: `apps/backend/test/fasting/meal-events.e2e-spec.ts`

**Interfaces:**
- Consumes: Task 2's `MealEventService`, `toMealEventOutput` and `FastingService.toOutput(fasting, extras)`.
- Produces:
  - `MealEventService.todayMealsByRegion(regionId: number, now?: Date): Promise<Map<number, MealEventOutput>>`.
  - `todayMealOf(fastingId: number, now?: Date): Promise<MealEventOutput | null>`.
  - `mealsOf(fastingId: number): Promise<MealEventOutput[]>`, which excludes conflict records and puts the newest first.
  - `recordRegistrationMeal(manager, { fastingId, regionId, servedAt, servedByUserId }): Promise<string>`.
  - `GET /fastings/:region` items carry `todayMeal`. `GET /fastings/:region/:id` carries `todayMeal` and `meals`. The create and update responses carry `todayMeal`.

- [ ] **Step 1: Write the failing e2e tests**

In `apps/backend/test/fasting/meal-events.e2e-spec.ts`, add inside the outer `describe`, after the `describe('confirm', …)` block:

```ts
  describe('reads', () => {
    it("lists tonight's meal with who served it", async () => {
      await createPerson(201);
      await createPerson(202);
      const clientEventId = randomUUID();
      await confirm(201, { clientEventId }).expect(HttpStatus.OK);

      const res = await request(server())
        .get(`/fastings/${regionId}`)
        .set(bearer(other))
        .expect(HttpStatus.OK);
      const byId = new Map(res.body.data.map((p) => [p.id, p]));
      expect((byId.get(201) as any).todayMeal).toMatchObject({
        eventId: clientEventId,
        servedBy: { name: 'Volunteer' },
        revokedAt: null,
      });
      expect((byId.get(202) as any).todayMeal).toBeNull();
    });

    it('shows every meal of one person, newest first, with who served it', async () => {
      await createPerson(203);
      await confirm(203, { clientEventId: randomUUID() }).expect(HttpStatus.OK);
      const res = await request(server())
        .get(`/fastings/${regionId}/203`)
        .set(bearer(volunteer))
        .expect(HttpStatus.OK);
      expect(res.body.data.meals).toHaveLength(1);
      expect(res.body.data.meals[0].servedBy.name).toBe('Volunteer');
      expect(res.body.data.todayMeal.eventId).toBe(res.body.data.meals[0].eventId);
    });

    it('records the meal handed over at registration as a meal event', async () => {
      const created = await createPerson(204, { cameToday: true });
      expect(created.body.data.todayMeal).toMatchObject({
        servedBy: { name: 'Volunteer' },
      });
      expect(await activeMeals(204)).toBe(1);
      const second = await confirm(204, { clientEventId: randomUUID() }).expect(
        HttpStatus.CONFLICT,
      );
      expect(second.body.error.details.servedBy.name).toBe('Volunteer');
    });

    it("keeps tonight's meal in the response of an edit", async () => {
      await createPerson(205);
      await confirm(205, { clientEventId: randomUUID() }).expect(HttpStatus.OK);
      const res = await request(server())
        .patch(`/fastings/${regionId}/205`)
        .set(bearer(volunteer))
        .send({
          firstName: 'Najwa',
          lastName: 'Chalbi',
          singleMeal: 2,
          familyMeal: 1,
          region: { id: regionId, name: 'Dar Sokra' },
        })
        .expect(HttpStatus.OK);
      expect(res.body.data.todayMeal).not.toBeNull();
    });
  });
```

- [ ] **Step 2: Run them to see them fail**

Run the backend e2e tests with pattern `meal-events.e2e`. Expected: FAIL, because `todayMeal` and `meals` are undefined and person 204 has 0 active meals.

- [ ] **Step 3: Add the read and registration helpers to `MealEventService`**

Append these methods to the `MealEventService` class:

```ts
  /** Tonight's active meal per person of a region (one query for a list). */
  async todayMealsByRegion(
    regionId: number,
    now: Date = new Date(),
  ): Promise<Map<number, MealEventOutput>> {
    const rows: MealEventRow[] = await this.dataSource.query(
      `${EVENT_SELECT}
       WHERE e."regionId" = $1 AND e."serviceDay" = $2
         AND e."revokedAt" IS NULL AND e."conflict" = false`,
      [regionId, this.serviceDay(now)],
    );
    return new Map(rows.map((row) => [row.fastingId, toMealEventOutput(row)]));
  }

  async todayMealOf(
    fastingId: number,
    now: Date = new Date(),
  ): Promise<MealEventOutput | null> {
    const row = await this.activeEventOn(
      this.dataSource.manager,
      fastingId,
      this.serviceDay(now),
    );
    return row ? toMealEventOutput(row) : null;
  }

  /** Every meal of a person, newest first, undone ones included. */
  async mealsOf(fastingId: number): Promise<MealEventOutput[]> {
    const rows: MealEventRow[] = await this.dataSource.query(
      `${EVENT_SELECT}
       WHERE e."fastingId" = $1 AND e."conflict" = false
       ORDER BY e."servedAt" DESC`,
      [fastingId],
    );
    return rows.map(toMealEventOutput);
  }

  /**
   * "Came today" at registration is a real meal: it blocks a second one and
   * can be undone like any other. The caller has already written
   * takenMeals / lastTakenMeal.
   */
  recordRegistrationMeal(
    manager: EntityManager,
    meal: {
      fastingId: number;
      regionId: number;
      servedAt: Date;
      servedByUserId: number;
    },
  ): Promise<string> {
    return this.insertActive(manager, { ...meal, id: null, deviceId: null });
  }
```

- [ ] **Step 4: Use them in `FastingService`**

In `apps/backend/src/fasting/services/fasting.service.ts`:

1. In `createFasting`, replace these lines:

```ts
    this.logger.log(ctx, `calling ${FastingRepository.name}.save`);
    const savedFasting = await this.repository.save(fasting);

    return this.toOutput(savedFasting);
```

with:

```ts
    this.logger.log(ctx, `calling ${FastingRepository.name}.save`);
    const savedFasting = await this.repository.manager.transaction(
      async (manager) => {
        const saved = await manager.save(Fasting, fasting);
        if (saved.lastTakenMeal && fasting.region?.id != null) {
          await this.meals.recordRegistrationMeal(manager, {
            fastingId: saved.id,
            regionId: fasting.region.id,
            servedAt: new Date(saved.lastTakenMeal),
            servedByUserId: actor.id,
          });
        }
        return saved;
      },
    );

    const todayMeal = savedFasting.lastTakenMeal
      ? await this.meals.todayMealOf(savedFasting.id)
      : null;
    return this.toOutput(savedFasting, { todayMeal });
```

2. In `getFastingsByRegion`, replace `return { fastings: fastings.map((f) => this.toOutput(f)), count };` with:

```ts
    const today = await this.meals.todayMealsByRegion(region);
    return {
      fastings: fastings.map((f) =>
        this.toOutput(f, { todayMeal: today.get(f.id) ?? null }),
      ),
      count,
    };
```

3. In `getFastingById`, replace `return this.toOutput(fasting);` with:

```ts
    const meals = await this.meals.mealsOf(fasting.id);
    const todayMeal = await this.meals.todayMealOf(fasting.id);
    return this.toOutput(fasting, { todayMeal, meals });
```

4. In `updateFasting`, replace `return this.toOutput(savedFasting);` with:

```ts
    const todayMeal = await this.meals.todayMealOf(savedFasting.id);
    return this.toOutput(savedFasting, { todayMeal });
```

- [ ] **Step 5: Update the `createFasting` unit tests**

In `apps/backend/src/fasting/services/fasting.service.spec.ts`, add `save: jest.fn()` to the `manager` mock object. Then replace the test `'saves a person with no meal history as not collected today'` with these two tests:

```ts
    it('saves a person with no meal history as not collected today', async () => {
      userService.getUserById.mockResolvedValue({ id: 7, region: { id: 1 } });
      repository.findOne.mockResolvedValue(null);
      manager.save.mockImplementation(async (_entity, fasting) => fasting);

      const result = await service.createFasting(ctx, {
        id: 43,
        firstName: 'X',
        lastName: 'Y',
        singleMeal: 1,
        familyMeal: 0,
        region: 1,
        lastTakenMeal: null,
        takenMeals: [],
      } as any);

      expect(manager.save).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({ lastTakenMeal: null, takenMeals: [] }),
      );
      expect(meals.recordRegistrationMeal).not.toHaveBeenCalled();
      expect(result.lastTakenMeal).toBeNull();
      expect(result.takenMeals).toEqual([]);
      expect(result.mealTakenToday).toBe(false);
    });

    it('records the meal of a person who came today as a meal event', async () => {
      const today = new Date();
      userService.getUserById.mockResolvedValue({ id: 7, region: { id: 1 } });
      repository.findOne.mockResolvedValue(null);
      manager.save.mockImplementation(async (_entity, fasting) => fasting);

      await service.createFasting(ctx, {
        id: 44,
        firstName: 'X',
        lastName: 'Y',
        singleMeal: 1,
        familyMeal: 0,
        region: 1,
        lastTakenMeal: today,
        takenMeals: [today],
      } as any);

      expect(meals.recordRegistrationMeal).toHaveBeenCalledWith(manager, {
        fastingId: 44,
        regionId: 1,
        servedAt: today,
        servedByUserId: 7,
      });
    });
```

The existing test `'refuses to overwrite an existing person ID'` asserts `expect(repository.save).not.toHaveBeenCalled();`. Change it to `expect(manager.save).not.toHaveBeenCalled();`.

- [ ] **Step 6: Run the tests**

Run the backend unit tests with pattern `fasting`. Expected: PASS. Run the backend e2e tests with pattern `.`. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add apps/backend
git commit -m "feat(backend): tonight's meal and meal history in reads; registration meal is a meal event

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Undo endpoint

**Files:**
- Create: `apps/backend/src/fasting/services/revoke-rules.ts`
- Create: `apps/backend/src/fasting/services/revoke-rules.spec.ts`
- Modify: `apps/backend/src/fasting/services/meal-event.service.ts`
- Modify: `apps/backend/src/fasting/services/fasting.service.ts`
- Modify: `apps/backend/src/fasting/controllers/fasting.controller.ts`
- Modify: `apps/backend/src/shared/configs/configuration.ts`
- Modify: `apps/backend/.env.template`
- Modify: `README.md` (the backend environment table)
- Test: `apps/backend/test/fasting/meal-events.e2e-spec.ts`

**Interfaces:**
- Consumes: Task 2's `MealEventService.findEvent` and `MealEventRow`, and Task 3's `todayMealOf`.
- Produces:
  - `decideRevoke(event, actor, now, { windowMinutes, timeZone }): 'allowed' | 'alreadyRevoked' | 'notAllowed' | 'windowExpired'`.
  - `MealEventService.revoke(ctx, eventId): Promise<{ fastingId: number; regionId: number }>`.
  - `FastingService.revokeMeal(ctx, eventId): Promise<FastingOutput>`.
  - The route `POST /fastings/meals/:eventId/revoke`. It returns `200` with the person; `403` with `UNDO_NOT_ALLOWED` or `UNDO_WINDOW_EXPIRED`; `404` with `MEAL_EVENT_NOT_FOUND`; and `400` for a non-UUID.
  - The config key `undoWindowMinutes`.

- [ ] **Step 1: Write the failing unit tests for the rule**

Create `apps/backend/src/fasting/services/revoke-rules.spec.ts`:

```ts
import { ROLE } from '../../auth/constants/role.constant';
import { decideRevoke } from './revoke-rules';

describe('decideRevoke', () => {
  const opts = { windowMinutes: 10, timeZone: 'Africa/Tunis' };
  const receivedAt = new Date('2027-02-21T17:00:00Z'); // 18:00 Tunis
  const event = {
    servedByUserId: 7,
    receivedAt,
    serviceDay: '2027-02-21',
    revokedAt: null,
  };
  const volunteer = { id: 7, roles: [ROLE.USER] };
  const otherVolunteer = { id: 8, roles: [ROLE.USER] };
  const admin = { id: 1, roles: [ROLE.ADMIN] };
  const at = (minutes: number) =>
    new Date(receivedAt.getTime() + minutes * 60_000);

  it('lets the volunteer who served it undo within the window, edge included', () => {
    expect(decideRevoke(event, volunteer, at(1), opts)).toBe('allowed');
    expect(decideRevoke(event, volunteer, at(10), opts)).toBe('allowed');
  });

  it('refuses that volunteer after the window', () => {
    expect(decideRevoke(event, volunteer, at(10.02), opts)).toBe('windowExpired');
  });

  it("refuses another volunteer, even within the window", () => {
    expect(decideRevoke(event, otherVolunteer, at(1), opts)).toBe('notAllowed');
  });

  it('refuses a volunteer on backfilled history (no server)', () => {
    expect(
      decideRevoke({ ...event, servedByUserId: null }, volunteer, at(1), opts),
    ).toBe('notAllowed');
  });

  it("lets an admin undo anyone's meal on its own service day", () => {
    expect(decideRevoke(event, admin, at(240), opts)).toBe('allowed'); // 22:00 Tunis
  });

  it('refuses an admin the next day', () => {
    expect(decideRevoke(event, admin, at(60 * 7), opts)).toBe('windowExpired'); // 01:00 Tunis next day
  });

  it('reports an already-undone meal as such, whoever asks', () => {
    const revoked = { ...event, revokedAt: at(2) };
    expect(decideRevoke(revoked, otherVolunteer, at(3), opts)).toBe('alreadyRevoked');
  });
});
```

- [ ] **Step 2: Run it to see it fail**

Run the backend unit tests with pattern `revoke-rules`. Expected: FAIL, because `./revoke-rules` can't be found.

- [ ] **Step 3: Write the rule**

Create `apps/backend/src/fasting/services/revoke-rules.ts`:

```ts
import { ROLE } from '../../auth/constants/role.constant';
import { localDayKey } from '../../shared/utils/local-day';

export type RevokeDecision =
  | 'allowed'
  | 'alreadyRevoked'
  | 'notAllowed'
  | 'windowExpired';

export interface RevocableEvent {
  servedByUserId: number | null;
  receivedAt: Date;
  /** YYYY-MM-DD in APP_TIMEZONE. */
  serviceDay: string;
  revokedAt: Date | null;
}

/**
 * Who may undo a meal (spec 2A §4.2): the volunteer who served it, within
 * `windowMinutes` of the server receiving it; or an admin, on the meal's own
 * service day. Undoing twice is not an error.
 */
export function decideRevoke(
  event: RevocableEvent,
  actor: { id: number; roles: string[] },
  now: Date,
  opts: { windowMinutes: number; timeZone: string },
): RevokeDecision {
  if (event.revokedAt) {
    return 'alreadyRevoked';
  }
  const isAdmin = actor.roles.includes(ROLE.ADMIN);
  if (isAdmin && event.serviceDay === localDayKey(now, opts.timeZone)) {
    return 'allowed';
  }
  if (event.servedByUserId !== actor.id) {
    return isAdmin ? 'windowExpired' : 'notAllowed';
  }
  const ageMs = now.getTime() - new Date(event.receivedAt).getTime();
  return ageMs <= opts.windowMinutes * 60_000 ? 'allowed' : 'windowExpired';
}
```

Run the backend unit tests with pattern `revoke-rules`. Expected: PASS (7 tests).

- [ ] **Step 4: Write the failing e2e tests**

In `apps/backend/test/fasting/meal-events.e2e-spec.ts`, add inside the outer `describe`, after the `describe('reads', …)` block:

```ts
  describe('undo', () => {
    const served = async (id: number, token = volunteer): Promise<string> => {
      await createPerson(id);
      const clientEventId = randomUUID();
      await confirm(id, { clientEventId }, token).expect(HttpStatus.OK);
      return clientEventId;
    };

    it('lets the volunteer undo their own meal, and the person can be served again', async () => {
      const eventId = await served(301);
      const res = await revoke(eventId).expect(HttpStatus.OK);
      expect(res.body.data).toMatchObject({
        id: 301,
        mealTakenToday: false,
        takenMeals: [],
        lastTakenMeal: null,
        todayMeal: null,
      });
      await confirm(301, { clientEventId: randomUUID() }).expect(HttpStatus.OK);
    });

    it('treats a second undo as done', async () => {
      const eventId = await served(302);
      await revoke(eventId).expect(HttpStatus.OK);
      await revoke(eventId).expect(HttpStatus.OK);
    });

    it("refuses another volunteer's undo", async () => {
      const eventId = await served(303);
      const res = await revoke(eventId, other).expect(HttpStatus.FORBIDDEN);
      expect(res.body.error.details.code).toBe('UNDO_NOT_ALLOWED');
    });

    it('refuses the volunteer after the undo window', async () => {
      const eventId = await served(304);
      await dbQuery(
        `UPDATE "meal_events" SET "receivedAt" = now() - interval '11 minutes' WHERE "id" = $1`,
        [eventId],
      );
      const res = await revoke(eventId).expect(HttpStatus.FORBIDDEN);
      expect(res.body.error.details.code).toBe('UNDO_WINDOW_EXPIRED');
    });

    it("lets an admin undo anyone's meal the same day, even after the window", async () => {
      const eventId = await served(305);
      await dbQuery(
        `UPDATE "meal_events" SET "receivedAt" = now() - interval '2 hours' WHERE "id" = $1`,
        [eventId],
      );
      await revoke(eventId, admin).expect(HttpStatus.OK);
    });

    it('answers a late retry of an undone confirm with the undone meal, not a new one', async () => {
      const eventId = await served(306);
      await revoke(eventId).expect(HttpStatus.OK);
      const replay = await confirm(306, { clientEventId: eventId }).expect(HttpStatus.OK);
      expect(replay.body.data.meal.revokedAt).not.toBeNull();
      expect(replay.body.data.todayMeal).toBeNull();
      expect(replay.body.data.mealTakenToday).toBe(false);
    });

    it('undoes a meal recorded at registration', async () => {
      const created = await createPerson(307, { cameToday: true });
      const eventId = created.body.data.todayMeal.eventId;
      const res = await revoke(eventId).expect(HttpStatus.OK);
      expect(res.body.data.takenMeals).toEqual([]);
      expect(res.body.data.mealTakenToday).toBe(false);
    });

    it("keeps older days' meals when tonight's is undone", async () => {
      await createPerson(308);
      const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
      await dbQuery(
        `UPDATE "fastings" SET "takenMeals" = ARRAY[$2::varchar], "lastTakenMeal" = $3 WHERE "id" = $1`,
        [308, yesterday.toISOString(), yesterday],
      );
      await dbQuery(
        `INSERT INTO "meal_events" ("fastingId","regionId","servedAt","serviceDay","source")
         VALUES ($1, $2, $3, ($3::timestamptz AT TIME ZONE 'Africa/Tunis')::date, 'backfill')`,
        [308, regionId, yesterday],
      );
      const clientEventId = randomUUID();
      await confirm(308, { clientEventId }).expect(HttpStatus.OK);

      const res = await revoke(clientEventId).expect(HttpStatus.OK);
      expect(res.body.data.takenMeals).toHaveLength(1);
      expect(new Date(res.body.data.takenMeals[0]).getTime()).toBe(yesterday.getTime());
      expect(new Date(res.body.data.lastTakenMeal).getTime()).toBe(yesterday.getTime());
    });

    it('returns 404 for an unknown meal and 400 for a malformed ID', async () => {
      const res = await revoke(randomUUID()).expect(HttpStatus.NOT_FOUND);
      expect(res.body.error.details.code).toBe('MEAL_EVENT_NOT_FOUND');
      await revoke('not-a-uuid').expect(HttpStatus.BAD_REQUEST);
    });
  });
```

Run the backend e2e tests with pattern `meal-events.e2e`. Expected: FAIL with 404s, because the route doesn't exist yet.

- [ ] **Step 5: Configure the window**

In `apps/backend/src/shared/configs/configuration.ts`, add after the `timezone` line:

```ts
  // How long a volunteer can undo their own meal confirm (spec 2A §4.2).
  undoWindowMinutes: parseInt(process.env.UNDO_WINDOW_MINUTES || '10', 10),
```

In `apps/backend/.env.template`, add the line `UNDO_WINDOW_MINUTES=10` after `APP_TIMEZONE=Africa/Tunis`.

In `README.md`, add this row to the backend environment table, after `APP_TIMEZONE`:

```
| `UNDO_WINDOW_MINUTES` | How long a volunteer can undo their own meal confirm. Default `10`; admins can undo until the end of the day |
```

- [ ] **Step 6: Implement the revoke in `MealEventService`**

In `apps/backend/src/fasting/services/meal-event.service.ts`, add `ForbiddenException` to the `@nestjs/common` import and `import { decideRevoke } from './revoke-rules';`. Then add these members to the class:

```ts
  private get undoWindowMinutes(): number {
    return this.configService.get<number>('undoWindowMinutes') ?? 10;
  }

  /**
   * Undoes a meal (spec 2A §4.2). The event is kept with revokedAt /
   * revokedByUserId; the person's history loses that meal.
   */
  async revoke(
    ctx: RequestContext,
    eventId: string,
  ): Promise<{ fastingId: number; regionId: number }> {
    this.logger.log(ctx, `${this.revoke.name} was called`);
    const actor: Actor = ctx.user;

    return this.dataSource.transaction(async (manager) => {
      const found = await this.findEvent(manager, eventId);
      if (!found) {
        throw new NotFoundException({
          message: 'Meal not found',
          code: FASTING_ERROR_CODES.MEAL_EVENT_NOT_FOUND,
        });
      }
      // Same lock order as confirm: the person first, then the event.
      await manager.query(
        `SELECT "id" FROM "fastings" WHERE "id" = $1 FOR UPDATE`,
        [found.fastingId],
      );
      const event = await this.findEvent(manager, eventId);
      const ids = { fastingId: event.fastingId, regionId: event.regionId };

      switch (
        decideRevoke(event, actor, new Date(), {
          windowMinutes: this.undoWindowMinutes,
          timeZone: this.timeZone,
        })
      ) {
        case 'alreadyRevoked':
          return ids;
        case 'notAllowed':
          throw new ForbiddenException({
            message: 'Only the volunteer who served this meal can undo it',
            code: FASTING_ERROR_CODES.UNDO_NOT_ALLOWED,
          });
        case 'windowExpired':
          throw new ForbiddenException({
            message: 'It is too late to undo this meal',
            code: FASTING_ERROR_CODES.UNDO_WINDOW_EXPIRED,
          });
        case 'allowed':
          break;
      }

      await manager.query(
        `UPDATE "meal_events" SET "revokedAt" = now(), "revokedByUserId" = $2 WHERE "id" = $1`,
        [eventId, actor.id],
      );
      if (!event.conflict) {
        await this.removeFromHistory(manager, event);
      }
      return ids;
    });
  }

  /** Dual-write of a revoke: drop that meal from takenMeals, recompute lastTakenMeal. */
  private async removeFromHistory(
    manager: EntityManager,
    event: MealEventRow,
  ): Promise<void> {
    const [row]: Array<{ takenMeals: string[] }> = await manager.query(
      `SELECT "takenMeals" FROM "fastings" WHERE "id" = $1`,
      [event.fastingId],
    );
    const taken = row?.takenMeals ?? [];
    // Compared as instants: entries are ISO strings, or dates written with
    // an offset by the registration path.
    const target = new Date(event.servedAt).getTime();
    const index = taken.findIndex((raw) => new Date(raw).getTime() === target);
    const remaining =
      index < 0 ? taken : [...taken.slice(0, index), ...taken.slice(index + 1)];

    const [latest]: Array<{ at: Date | null }> = await manager.query(
      `SELECT max("servedAt") AS "at" FROM "meal_events"
       WHERE "fastingId" = $1 AND "revokedAt" IS NULL AND "conflict" = false`,
      [event.fastingId],
    );
    await manager.query(
      `UPDATE "fastings"
       SET "takenMeals" = $2::varchar[], "lastTakenMeal" = $3, "updatedAt" = now()
       WHERE "id" = $1`,
      [event.fastingId, remaining, latest?.at ? new Date(latest.at) : null],
    );
  }
```

- [ ] **Step 7: Expose it**

In `apps/backend/src/fasting/services/fasting.service.ts`, add after `confirmMeal`:

```ts
  /** Undoes a meal (spec 2A §4.2) and returns the person as it now is. */
  async revokeMeal(
    ctx: RequestContext,
    eventId: string,
  ): Promise<FastingOutput> {
    this.logger.log(ctx, `${this.revokeMeal.name} was called`);

    const { fastingId, regionId } = await this.meals.revoke(ctx, eventId);
    const fasting = await this.repository.getByIdAndRegion(fastingId, regionId);
    const todayMeal = await this.meals.todayMealOf(fastingId);
    return this.toOutput(fasting, { todayMeal });
  }
```

In `apps/backend/src/fasting/controllers/fasting.controller.ts`, add `HttpCode` and `ParseUUIDPipe` to the `@nestjs/common` import. Then add this method directly after `confirmFastingMeal`:

```ts
  @Post('meals/:eventId/revoke')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Undo a meal confirmation (spec 2A §4.2)',
  })
  @ApiResponse({
    status: HttpStatus.OK,
    type: SwaggerBaseApiResponse(FastingOutput),
  })
  @ApiResponse({
    status: HttpStatus.FORBIDDEN,
    description:
      "details.code = UNDO_NOT_ALLOWED (someone else's meal) or UNDO_WINDOW_EXPIRED",
    type: BaseApiErrorResponse,
  })
  @ApiResponse({
    status: HttpStatus.NOT_FOUND,
    description: 'details.code = MEAL_EVENT_NOT_FOUND',
    type: BaseApiErrorResponse,
  })
  @UseInterceptors(ClassSerializerInterceptor)
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async revokeMeal(
    @ReqContext() ctx: RequestContext,
    @Param('eventId', new ParseUUIDPipe()) eventId: string,
  ): Promise<BaseApiResponse<FastingOutput>> {
    this.logger.log(ctx, `${this.revokeMeal.name} was called`);

    const fasting = await this.fastingService.revokeMeal(ctx, eventId);
    return { data: fasting, meta: {} };
  }
```

- [ ] **Step 8: Run everything on the backend**

Run the backend unit tests with pattern `.`, then the backend e2e tests with pattern `.`, then `npm run lint`. Expected: all PASS with no lint errors.

- [ ] **Step 9: Commit**

```bash
git add apps/backend README.md
git commit -m "feat(backend): undo a meal confirm (own within UNDO_WINDOW_MINUTES, admins same day)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: App domain: meal events, undo rules, UUIDs, richer failures

**Files:**
- Create: `apps/mobile/lib/features/people/domain/meal_event.dart`
- Modify: `apps/mobile/lib/features/people/domain/fasting_person.dart`
- Create: `apps/mobile/lib/features/people/domain/undo_rules.dart`
- Create: `apps/mobile/lib/core/utils/uuid.dart`
- Modify: `apps/mobile/lib/core/network/app_failure.dart`
- Test: `apps/mobile/test/domain/meal_event_test.dart`, `apps/mobile/test/domain/undo_rules_test.dart`, `apps/mobile/test/core/uuid_test.dart`, `apps/mobile/test/data/app_failure_test.dart`

**Interfaces:**
- Produces:
  - `MealEvent { String eventId; DateTime servedAt; int? servedById; String? servedByName; DateTime? revokedAt; bool get isActive; Map<String, dynamic> toJson(); static MealEvent? tryParse(Object? json) }`.
  - `FastingPerson` gains `MealEvent? todayMeal`, `List<MealEvent> meals`, `MealEvent? todayMealAt(DateTime now)`, `Map<String, dynamic> toJson()`, `static const receivedAtKey = '_receivedAt'`, and the `copyWith` parameters `todayMeal`, `clearTodayMeal` and `meals`.
  - `const serverUndoWindow = Duration(minutes: 10)` and `MealEvent? undoableMeal(FastingPerson person, User? user, DateTime now)`.
  - `String newUuidV4()`.
  - `MealAlreadyTakenFailure.servedByName`, and `UndoRefusedFailure(code)` with `tooLate`, `windowExpired` and `notAllowed`.

- [ ] **Step 1: Write the failing tests**

Create `apps/mobile/test/domain/meal_event_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';

void main() {
  final received = DateTime(2025, 3, 5, 18, 30);
  Map<String, dynamic> meal(String id, String at, {String? by}) => {
    'eventId': id,
    'servedAt': at,
    'servedBy': by == null ? null : {'id': 2, 'name': by},
    'revokedAt': null,
  };
  final json = <String, dynamic>{
    'id': 7,
    'firstName': 'Najwa',
    'lastName': 'Chalbi',
    'cin': '01234567',
    'phone': '22123456',
    'singleMeal': 2,
    'familyMeal': 1,
    'lastTakenMeal': '2025-03-05T17:10:00.000Z',
    'takenMeals': ['2025-03-05T17:10:00.000Z', '2025-03-04T17:00:00.000Z'],
    'mealTakenToday': true,
    'todayMeal': meal('e1', '2025-03-05T17:10:00.000Z', by: 'Vol One'),
    'meals': [
      meal('e1', '2025-03-05T17:10:00.000Z', by: 'Vol One'),
      meal('e0', '2025-03-04T17:00:00.000Z'),
    ],
    'region': {'id': 1, 'name': 'Dar Sokra'},
  };

  test("reads tonight's meal and the history with who served", () {
    final p = FastingPerson.fromJson(json, receivedAt: received);
    expect(p.todayMeal!.eventId, 'e1');
    expect(p.todayMeal!.servedByName, 'Vol One');
    expect(p.todayMeal!.servedById, 2);
    expect(p.meals.map((m) => m.eventId), ['e1', 'e0']);
    expect(p.meals.last.servedByName, isNull);
  });

  test("tonight's meal is only good for the day it was received", () {
    final p = FastingPerson.fromJson(json, receivedAt: received);
    expect(p.todayMealAt(DateTime(2025, 3, 5, 23)), isNotNull);
    expect(p.todayMealAt(DateTime(2025, 3, 6, 18)), isNull);
  });

  test("an undone meal is not tonight's meal", () {
    final p = FastingPerson.fromJson({
      ...json,
      'todayMeal': {
        ...meal('e1', '2025-03-05T17:10:00.000Z'),
        'revokedAt': '2025-03-05T17:12:00.000Z',
      },
    }, receivedAt: received);
    expect(p.todayMealAt(received), isNull);
  });

  test('a malformed meal is ignored, not fatal', () {
    final p = FastingPerson.fromJson({
      ...json,
      'todayMeal': {'eventId': 5},
      'meals': [
        {'eventId': 5},
        meal('e0', '2025-03-04T17:00:00.000Z'),
      ],
    });
    expect(p.todayMeal, isNull);
    expect(p.meals.map((m) => m.eventId), ['e0']);
  });

  test('toJson round-trips, keeping when it was received', () {
    final p = FastingPerson.fromJson(json, receivedAt: received);
    final back = FastingPerson.fromJson(
      jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
    );
    expect(back.id, 7);
    expect(back.fullName, 'Najwa Chalbi');
    expect(back.cin, '01234567');
    expect(back.phone, '22123456');
    expect(back.region!.id, 1);
    expect(back.takenMeals, p.takenMeals);
    expect(back.receivedAt, received);
    expect(back.todayMeal!.servedByName, 'Vol One');
    expect(back.meals, hasLength(2));
    // The served flag still expires with the day it arrived.
    expect(back.isMealTakenToday(DateTime(2025, 3, 5, 22)), isTrue);
    expect(back.isMealTakenToday(DateTime(2025, 3, 6, 18)), isFalse);
  });
}
```

Create `apps/mobile/test/domain/undo_rules_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/auth/domain/user.dart';
import 'package:iftar_mobile/features/people/domain/meal_event.dart';
import 'package:iftar_mobile/features/people/domain/undo_rules.dart';

import '../support/fakes.dart';

void main() {
  final servedAt = testNow.subtract(const Duration(minutes: 3));
  final mine = MealEvent(
    eventId: 'e1',
    servedAt: servedAt,
    servedById: testUser.id,
    servedByName: testUser.name,
  );
  final p = person(101, takenToday: true).copyWith(
    todayMeal: mine,
    receivedAt: testNow,
  );
  const admin = User(
    id: 1,
    name: 'Admin',
    username: 'admin',
    email: 'admin@example.com',
    roles: ['ADMIN'],
    isAccountDisabled: false,
  );

  test('offers my own meal within 10 minutes, edge included', () {
    expect(undoableMeal(p, testUser, testNow), mine);
    expect(undoableMeal(p, testUser, servedAt.add(serverUndoWindow)), mine);
  });

  test('not after 10 minutes', () {
    expect(
      undoableMeal(
        p,
        testUser,
        servedAt.add(serverUndoWindow + const Duration(seconds: 1)),
      ),
      isNull,
    );
  });

  test("not someone else's meal, unless I'm an admin", () {
    final theirs = p.copyWith(
      todayMeal: MealEvent(eventId: 'e2', servedAt: servedAt, servedById: 99),
    );
    expect(undoableMeal(theirs, testUser, testNow), isNull);
    expect(undoableMeal(theirs, admin, testNow)?.eventId, 'e2');
  });

  test('nothing to undo without a meal tonight, or signed out', () {
    expect(undoableMeal(person(102), testUser, testNow), isNull);
    expect(undoableMeal(p, null, testNow), isNull);
  });
}
```

Create `apps/mobile/test/core/uuid_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/utils/uuid.dart';

void main() {
  test('is a random (v4) UUID, different every time', () {
    final v4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    final ids = {for (var i = 0; i < 1000; i++) newUuidV4()};
    expect(ids, hasLength(1000));
    expect(ids.every(v4.hasMatch), isTrue);
  });
}
```

Append this group inside `main()` of `apps/mobile/test/data/app_failure_test.dart`. Add `import 'package:iftar_mobile/core/network/app_failure.dart';` if it isn't imported already.

```dart
  group('spec 2A', () {
    test('409 says who served, from the new fields', () {
      final f = failureFromResponse(409, {
        'error': {
          'details': {
            'code': 'MEAL_ALREADY_TAKEN',
            'servedAt': '2025-03-05T17:10:00.000Z',
            'lastTakenMeal': '2025-03-05T17:10:00.000Z',
            'servedBy': {'id': 2, 'name': 'Sami'},
          },
        },
      });
      expect(f, isA<MealAlreadyTakenFailure>());
      f as MealAlreadyTakenFailure;
      expect(f.servedByName, 'Sami');
      expect(f.takenAt, DateTime.parse('2025-03-05T17:10:00.000Z').toLocal());
    });

    test('409 from an older backend still gives the time', () {
      final f =
          failureFromResponse(409, {
                'error': {
                  'details': {
                    'code': 'MEAL_ALREADY_TAKEN',
                    'lastTakenMeal': '2025-03-05T17:10:00.000Z',
                  },
                },
              })
              as MealAlreadyTakenFailure;
      expect(f.takenAt, isNotNull);
      expect(f.servedByName, isNull);
    });

    test('403 on undo carries the reason', () {
      AppFailure forbidden(String? code) => failureFromResponse(403, {
        'error': {
          'details': {'code': ?code},
        },
      });
      expect(
        (forbidden('UNDO_WINDOW_EXPIRED') as UndoRefusedFailure).tooLate,
        isTrue,
      );
      expect(
        (forbidden('UNDO_NOT_ALLOWED') as UndoRefusedFailure).tooLate,
        isFalse,
      );
      expect(forbidden(null), isNot(isA<UndoRefusedFailure>()));
      expect(forbidden(null), isA<ForbiddenFailure>());
    });
  });
```

- [ ] **Step 2: Run them to see them fail**

Run Flutter with `test/domain/meal_event_test.dart test/domain/undo_rules_test.dart test/core/uuid_test.dart test/data/app_failure_test.dart`. Expected: compile errors, because `meal_event.dart`, `undo_rules.dart`, `uuid.dart`, `todayMeal` and `UndoRefusedFailure` don't exist yet.

- [ ] **Step 3: Write `MealEvent`**

Create `apps/mobile/lib/features/people/domain/meal_event.dart`:

```dart
/// One meal handed over, as the server recorded it (spec 2A §4).
class MealEvent {
  const MealEvent({
    required this.eventId,
    required this.servedAt,
    this.servedById,
    this.servedByName,
    this.revokedAt,
  });

  factory MealEvent.fromJson(Map<String, dynamic> json) {
    final servedBy = json['servedBy'];
    final revoked = json['revokedAt'];
    final name = servedBy is Map ? servedBy['name'] : null;
    return MealEvent(
      eventId: json['eventId'] as String,
      servedAt: DateTime.parse(json['servedAt'] as String).toLocal(),
      servedById: servedBy is Map ? (servedBy['id'] as num?)?.toInt() : null,
      servedByName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : null,
      revokedAt: revoked is String
          ? DateTime.tryParse(revoked)?.toLocal()
          : null,
    );
  }

  /// Null for anything that isn't a well-formed meal: one bad entry must not
  /// hide the person.
  static MealEvent? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return MealEvent.fromJson(json);
    } on Object {
      return null;
    }
  }

  final String eventId;
  final DateTime servedAt;

  /// Null for history recorded before served-by existed.
  final int? servedById;
  final String? servedByName;

  /// Set once undone.
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'servedAt': servedAt.toUtc().toIso8601String(),
    'servedBy': servedById == null
        ? null
        : {'id': servedById, 'name': servedByName ?? ''},
    'revokedAt': revokedAt?.toUtc().toIso8601String(),
  };
}
```

- [ ] **Step 4: Extend `FastingPerson`**

In `apps/mobile/lib/features/people/domain/fasting_person.dart`:

1. Add `import 'meal_event.dart';`.
2. Add `this.todayMeal,` and `this.meals = const [],` at the end of the constructor's parameter list.
3. Replace the factory with:

```dart
  /// [receivedAt] is when the response arrived; see [FastingPerson.receivedAt].
  /// A copy saved on the phone (see [toJson]) carries its own, under
  /// [receivedAtKey].
  factory FastingPerson.fromJson(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
  }) {
    final region = json['region'];
    final lastTaken = json['lastTakenMeal'];
    final savedReceivedAt = json[receivedAtKey];
    return FastingPerson(
      id: (json['id'] as num).toInt(),
      firstName: ((json['firstName'] as String?) ?? '').trim(),
      lastName: ((json['lastName'] as String?) ?? '').trim(),
      cin: _nonEmpty(json['cin']),
      phone: _nonEmpty(json['phone']),
      comment: _nonEmpty(json['comment']),
      singleMeal: (json['singleMeal'] as num?)?.toInt() ?? 0,
      familyMeal: (json['familyMeal'] as num?)?.toInt() ?? 0,
      lastTakenMeal: lastTaken is String
          ? DateTime.tryParse(lastTaken)?.toLocal()
          : null,
      takenMeals:
          ((json['takenMeals'] as List?) ?? const [])
              .map((e) => e is String ? DateTime.tryParse(e)?.toLocal() : null)
              .whereType<DateTime>()
              .toList()
            ..sort((a, b) => b.compareTo(a)),
      mealTakenTodayFromServer: json['mealTakenToday'] as bool?,
      receivedAt:
          receivedAt ??
          (savedReceivedAt is String
              ? DateTime.tryParse(savedReceivedAt)?.toLocal()
              : null),
      region: region is Map<String, dynamic> ? Region.fromJson(region) : null,
      todayMeal: MealEvent.tryParse(json['todayMeal']),
      meals: [
        for (final m in (json['meals'] as List?) ?? const [])
          ?MealEvent.tryParse(m),
      ],
    );
  }

  /// Key of [receivedAt] in [toJson].
  static const receivedAtKey = '_receivedAt';
```

4. Add these fields after `final Region? region;`:

```dart
  /// Tonight's meal as the server last described it: who served it, and its
  /// ID for Undo. Null from an older backend.
  final MealEvent? todayMeal;

  /// Every meal, newest first. Only a single-person read fills it.
  final List<MealEvent> meals;
```

5. Add these methods after `isMealTakenToday`:

```dart
  /// [todayMeal] while it can still be trusted: like the served flag, it
  /// describes the day it was received only.
  MealEvent? todayMealAt(DateTime now) {
    final meal = todayMeal;
    if (meal == null || !meal.isActive) return null;
    final received = receivedAt;
    if (received != null && !isSameDay(received.toLocal(), now.toLocal())) {
      return null;
    }
    return meal;
  }

  /// Server-shaped JSON, for the copy of the list saved on the phone
  /// (spec 2A §5.4). [receivedAt] travels with it, so a served flag still
  /// expires at midnight.
  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'cin': cin,
    'phone': phone,
    'comment': comment,
    'singleMeal': singleMeal,
    'familyMeal': familyMeal,
    'lastTakenMeal': lastTakenMeal?.toUtc().toIso8601String(),
    'takenMeals': [for (final t in takenMeals) t.toUtc().toIso8601String()],
    'mealTakenToday': mealTakenTodayFromServer,
    'todayMeal': todayMeal?.toJson(),
    'meals': [for (final m in meals) m.toJson()],
    'region': region?.toJson(),
    receivedAtKey: receivedAt?.toUtc().toIso8601String(),
  };
```

6. Replace `copyWith` with:

```dart
  FastingPerson copyWith({
    String? phone,
    String? comment,
    DateTime? lastTakenMeal,
    List<DateTime>? takenMeals,
    bool? mealTakenTodayFromServer,
    DateTime? receivedAt,
    MealEvent? todayMeal,
    bool clearTodayMeal = false,
    List<MealEvent>? meals,
  }) => FastingPerson(
    id: id,
    firstName: firstName,
    lastName: lastName,
    cin: cin,
    phone: phone ?? this.phone,
    comment: comment ?? this.comment,
    singleMeal: singleMeal,
    familyMeal: familyMeal,
    lastTakenMeal: lastTakenMeal ?? this.lastTakenMeal,
    takenMeals: takenMeals ?? this.takenMeals,
    mealTakenTodayFromServer:
        mealTakenTodayFromServer ?? this.mealTakenTodayFromServer,
    receivedAt: receivedAt ?? this.receivedAt,
    region: region,
    todayMeal: clearTodayMeal ? null : (todayMeal ?? this.todayMeal),
    meals: meals ?? this.meals,
  );
```

- [ ] **Step 5: Write the undo rule and the UUID helper**

Create `apps/mobile/lib/features/people/domain/undo_rules.dart`:

```dart
import '../../auth/domain/user.dart';
import 'fasting_person.dart';
import 'meal_event.dart';

/// The server accepts an undo from the volunteer who served the meal for
/// this long after it received the confirm (UNDO_WINDOW_MINUTES, spec 2A §4.2).
const serverUndoWindow = Duration(minutes: 10);

/// The meal [user] may still undo for [person], or null. Mirrors the
/// server's rule so the button only shows when it can work; the server
/// still decides. Admins may undo any meal of the day.
MealEvent? undoableMeal(FastingPerson person, User? user, DateTime now) {
  final meal = person.todayMealAt(now);
  if (meal == null || user == null) return null;
  if (user.roles.contains('ADMIN')) return meal;
  if (meal.servedById != user.id) return null;
  return now.difference(meal.servedAt) <= serverUndoWindow ? meal : null;
}
```

Create `apps/mobile/lib/core/utils/uuid.dart`:

```dart
import 'dart:math';

final _random = Random.secure();

/// A random (version 4) UUID, e.g. a confirm's `clientEventId`.
String newUuidV4() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
```

- [ ] **Step 6: Richer failures**

In `apps/mobile/lib/core/network/app_failure.dart`:

1. Replace `MealAlreadyTakenFailure` with:

```dart
/// The person already collected today's meal (409 MEAL_ALREADY_TAKEN).
final class MealAlreadyTakenFailure extends ConflictFailure {
  const MealAlreadyTakenFailure({this.takenAt, this.servedByName})
    : super('Meal already collected today', code: codeValue);

  static const codeValue = 'MEAL_ALREADY_TAKEN';

  final DateTime? takenAt;

  /// Who served it, when the server knows (spec 2A §4.1).
  final String? servedByName;
}
```

2. Add after `ForbiddenFailure`:

```dart
/// 403 on undo: someone else's meal, or too late (spec 2A §4.2).
final class UndoRefusedFailure extends ForbiddenFailure {
  const UndoRefusedFailure(this.code)
    : super('This meal can no longer be undone.');

  static const windowExpired = 'UNDO_WINDOW_EXPIRED';
  static const notAllowed = 'UNDO_NOT_ALLOWED';

  final String code;

  bool get tooLate => code == windowExpired;
}
```

3. In `failureFromResponse`, replace `case 403: return const ForbiddenFailure();` with:

```dart
    case 403:
      if (code == UndoRefusedFailure.windowExpired ||
          code == UndoRefusedFailure.notAllowed) {
        return UndoRefusedFailure(code!);
      }
      return const ForbiddenFailure();
```

Then replace the `MEAL_ALREADY_TAKEN` branch inside `case 409:` with:

```dart
      if (code == MealAlreadyTakenFailure.codeValue) {
        final at = details is Map
            ? (details['servedAt'] ?? details['lastTakenMeal'])
            : null;
        final servedBy = details is Map ? details['servedBy'] : null;
        final name = servedBy is Map ? servedBy['name'] : null;
        return MealAlreadyTakenFailure(
          takenAt: at is String ? DateTime.tryParse(at)?.toLocal() : null,
          servedByName: name is String && name.trim().isNotEmpty
              ? name.trim()
              : null,
        );
      }
```

- [ ] **Step 7: Run the tests**

Run Flutter with `test/domain test/core/uuid_test.dart test/data/app_failure_test.dart`. Expected: PASS. Then run `flutter test` (all). Expected: PASS, because nothing else has changed behaviour yet.

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/lib apps/mobile/test
git commit -m "feat(mobile): meal events, undo rule, UUIDs, served-by and undo-refused failures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: App data layer: confirm IDs, undo call, shorter timeouts, device ID

**Files:**
- Modify: `apps/mobile/lib/core/network/api_client.dart`
- Modify: `apps/mobile/lib/features/people/data/people_repository.dart`
- Create: `apps/mobile/lib/core/storage/device_id.dart`
- Modify: `apps/mobile/test/support/fakes.dart`
- Modify: `apps/mobile/test/data/people_repository_stamp_test.dart` (the stub's `patch` signature)
- Test: `apps/mobile/test/data/people_repository_meal_test.dart`, `apps/mobile/test/core/device_id_test.dart`

**Interfaces:**
- Consumes: `MealEvent` and `UndoRefusedFailure` (Task 5).
- Produces:
  - `ApiClient.mutationTimeout` (15 s); `post(..., {Duration? timeout})` and `patch(..., {Duration? timeout})`.
  - `PeopleRepository.confirmMeal(regionId, id, {phone, comment, clientEventId, deviceId})` and `PeopleRepository.revokeMeal(String eventId)`.
  - `deviceIdProvider: FutureProvider<String?>`.
  - Test fakes: `FakePeopleRepository.events`, `lastClientEventId`, `lastDeviceId`, `revokeCalls`, `nextRevokeFailure` and `revokeGate`; `person(..., todayMeal:)`; and a `testOverrides` that overrides `deviceIdProvider` with `'inst-test'`.

- [ ] **Step 1: Write the failing tests**

Create `apps/mobile/test/data/people_repository_meal_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/api_client.dart';
import 'package:iftar_mobile/features/people/data/people_repository.dart';

class _RecordingApi extends ApiClient {
  _RecordingApi() : super(Dio());

  String? path;
  Object? body;
  Duration? timeout;

  static const person = {
    'id': 7,
    'firstName': 'Najwa',
    'lastName': 'Chalbi',
    'singleMeal': 1,
    'familyMeal': 0,
    'mealTakenToday': true,
    'todayMeal': {
      'eventId': '6f1c2c55-7a8e-4d39-9b0e-6c7c1f0a9d11',
      'servedAt': '2025-03-05T17:30:00.000Z',
      'servedBy': {'id': 2, 'name': 'Vol One'},
      'revokedAt': null,
    },
  };

  @override
  Future<ApiEnvelope> patch(
    String path, {
    Object? body,
    Duration? timeout,
  }) async {
    this.path = path;
    this.body = body;
    this.timeout = timeout;
    return const ApiEnvelope(person, {});
  }

  @override
  Future<ApiEnvelope> post(
    String path, {
    Object? body,
    Map<String, dynamic>? extra,
    Duration? timeout,
  }) async {
    this.path = path;
    this.body = body;
    this.timeout = timeout;
    return const ApiEnvelope({
      ...person,
      'todayMeal': null,
      'mealTakenToday': false,
    }, {});
  }
}

void main() {
  late _RecordingApi api;
  late ApiPeopleRepository repo;

  setUp(() {
    api = _RecordingApi();
    repo = ApiPeopleRepository(api, clock: () => DateTime(2025, 3, 5, 18, 30));
  });

  test('a confirm sends its clientEventId and device ID, with the short timeout', () async {
    final p = await repo.confirmMeal(
      1,
      7,
      phone: ' 22123456 ',
      clientEventId: 'c-1',
      deviceId: 'inst-x',
    );
    expect(api.path, '/fastings/confirm/1/7');
    expect(api.body, {
      'phone': '22123456',
      'clientEventId': 'c-1',
      'deviceId': 'inst-x',
    });
    expect(api.timeout, ApiClient.mutationTimeout);
    expect(p.todayMeal!.servedByName, 'Vol One');
  });

  test('an undo posts to the revoke route, with the short timeout', () async {
    final p = await repo.revokeMeal('6f1c2c55-7a8e-4d39-9b0e-6c7c1f0a9d11');
    expect(
      api.path,
      '/fastings/meals/6f1c2c55-7a8e-4d39-9b0e-6c7c1f0a9d11/revoke',
    );
    expect(api.timeout, ApiClient.mutationTimeout);
    expect(p.todayMeal, isNull);
    expect(p.isMealTakenToday(DateTime(2025, 3, 5, 19)), isFalse);
  });
}
```

Create `apps/mobile/test/core/device_id_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/settings/settings_controller.dart';
import 'package:iftar_mobile/core/settings/settings_storage.dart';
import 'package:iftar_mobile/core/storage/device_id.dart';

import '../support/storage.dart';

void main() {
  test('is generated once and kept', () async {
    final storage = MemorySettingsStorage();
    ProviderContainer open() => ProviderContainer.test(
      overrides: [settingsStorageProvider.overrideWithValue(storage)],
    );
    final first = await open().read(deviceIdProvider.future);
    final second = await open().read(deviceIdProvider.future);
    expect(first, startsWith('inst-'));
    expect(first!.length, lessThanOrEqualTo(64));
    expect(second, first);
  });

  test('a keystore that refuses writes gives no ID instead of failing', () async {
    final container = ProviderContainer.test(
      overrides: [
        settingsStorageProvider.overrideWithValue(ThrowingWriteStorage()),
      ],
    );
    expect(await container.read(deviceIdProvider.future), isNull);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run Flutter with `test/data/people_repository_meal_test.dart test/core/device_id_test.dart`. Expected: compile errors (the `timeout` parameter, `mutationTimeout`, `revokeMeal` and `device_id.dart` don't exist yet).

- [ ] **Step 3: Per-request timeouts in `ApiClient`**

In `apps/mobile/lib/core/network/api_client.dart`, add after `baseOptions`:

```dart
  /// Confirm and undo normally answer fast. When they don't, a retry is
  /// safe (same clientEventId), so give up sooner than the 20 s default
  /// (spec 2A §5.1).
  static const mutationTimeout = Duration(seconds: 15);
```

Then replace `post` and `patch` with:

```dart
  Future<ApiEnvelope> post(
    String path, {
    Object? body,
    Map<String, dynamic>? extra,
    Duration? timeout,
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: body,
      options: Options(
        extra: extra,
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    ),
  );

  Future<ApiEnvelope> patch(String path, {Object? body, Duration? timeout}) =>
      _send(
        () => _dio.patch<dynamic>(
          path,
          data: body,
          options: Options(sendTimeout: timeout, receiveTimeout: timeout),
        ),
      );
```

In `apps/mobile/test/data/people_repository_stamp_test.dart`, change the stub's override to the new signature:

```dart
  @override
  Future<ApiEnvelope> patch(
    String path, {
    Object? body,
    Duration? timeout,
  }) async => const ApiEnvelope(person, {});
```

Then run `grep -rn "extends ApiClient" apps/mobile/test` and give every other `post` and `patch` override the same new parameters.

- [ ] **Step 4: The repository**

In `apps/mobile/lib/features/people/data/people_repository.dart`, replace the interface's `confirmMeal` declaration with:

```dart
  /// Records today's meal. [clientEventId] identifies this confirm: a retry
  /// must reuse it, so the server answers with the original meal instead of
  /// recording a second one. Throws `MealAlreadyTakenFailure` when the person
  /// already collected today.
  Future<FastingPerson> confirmMeal(
    int regionId,
    int id, {
    String? phone,
    String? comment,
    String? clientEventId,
    String? deviceId,
  });

  /// Undoes a meal (spec 2A §4.2). Throws `UndoRefusedFailure` when the
  /// server refuses (someone else's meal, or too late).
  Future<FastingPerson> revokeMeal(String eventId);
```

Then replace the implementation's `confirmMeal` with these two methods:

```dart
  @override
  Future<FastingPerson> confirmMeal(
    int regionId,
    int id, {
    String? phone,
    String? comment,
    String? clientEventId,
    String? deviceId,
  }) async {
    final envelope = await _api.patch(
      '/fastings/confirm/$regionId/$id',
      body: {
        'phone': ?phone?.trim(),
        'comment': ?comment?.trim(),
        'clientEventId': ?clientEventId,
        'deviceId': ?deviceId,
      },
      timeout: ApiClient.mutationTimeout,
    );
    return _person(envelope.object);
  }

  @override
  Future<FastingPerson> revokeMeal(String eventId) async {
    final envelope = await _api.post(
      '/fastings/meals/$eventId/revoke',
      timeout: ApiClient.mutationTimeout,
    );
    return _person(envelope.object);
  }
```

- [ ] **Step 5: Device ID**

Create `apps/mobile/lib/core/storage/device_id.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_controller.dart';
import '../utils/uuid.dart';

const _deviceIdKey = 'device_id';

/// This installation's ID, sent with each confirm for the audit trail
/// (spec 2A §5.1). Generated once and kept with the settings, so it survives
/// logout. Best effort: when the keystore fails, confirms go without it.
final deviceIdProvider = FutureProvider<String?>((ref) async {
  final storage = ref.read(settingsStorageProvider);
  try {
    final existing = await storage.read(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = 'inst-${newUuidV4()}';
    await storage.write(_deviceIdKey, id);
    return id;
  } on Object {
    return null;
  }
});
```

- [ ] **Step 6: Update the test fakes**

In `apps/mobile/test/support/fakes.dart`:

1. Add these imports:

```dart
import 'package:iftar_mobile/core/storage/device_id.dart';
import 'package:iftar_mobile/features/people/domain/meal_event.dart';
```

2. Give `person(...)` an optional `MealEvent? todayMeal` named parameter and pass `todayMeal: todayMeal` to the `FastingPerson` it builds.

3. Add these fields to `FakePeopleRepository`:

```dart
  /// clientEventId (or a generated ID) → person ID, like meal_events.
  final Map<String, int> events = {};
  String? lastClientEventId;
  String? lastDeviceId;
  int revokeCalls = 0;
  AppFailure? nextRevokeFailure;

  /// When set, `revokeMeal` waits for it (after counting the call).
  Completer<void>? revokeGate;
```

4. Replace `confirmMeal` with these two methods:

```dart
  @override
  Future<FastingPerson> confirmMeal(
    int regionId,
    int id, {
    String? phone,
    String? comment,
    String? clientEventId,
    String? deviceId,
  }) async {
    confirmCalls++;
    lastConfirmBody = (phone: phone, comment: comment);
    lastClientEventId = clientEventId;
    lastDeviceId = deviceId;
    final confirmGate = this.confirmGate;
    if (confirmGate != null) await confirmGate.future;
    final failure = nextConfirmFailure;
    if (failure != null && !applyThenFailConfirm) {
      nextConfirmFailure = null;
      throw failure;
    }
    final p = people[id];
    if (p == null) throw const NotFoundFailure();
    // A retry of a confirm already recorded gets that meal back (spec 2A §4.1).
    if (clientEventId != null && events[clientEventId] == id) return p;
    if (p.isMealTakenToday(testNow)) {
      throw MealAlreadyTakenFailure(
        takenAt: p.lastTakenMeal,
        servedByName: p.todayMeal?.servedByName,
      );
    }
    final eventId = clientEventId ?? 'evt-$confirmCalls';
    events[eventId] = id;
    final updated = p.copyWith(
      phone: phone,
      comment: comment,
      lastTakenMeal: testNow,
      mealTakenTodayFromServer: true,
      takenMeals: [testNow, ...p.takenMeals],
      todayMeal: MealEvent(
        eventId: eventId,
        servedAt: testNow,
        servedById: testUser.id,
        servedByName: testUser.name,
      ),
    );
    people[id] = updated;
    if (failure != null) {
      nextConfirmFailure = null;
      applyThenFailConfirm = false;
      throw failure;
    }
    return updated;
  }

  @override
  Future<FastingPerson> revokeMeal(String eventId) async {
    revokeCalls++;
    final gate = revokeGate;
    if (gate != null) await gate.future;
    final failure = nextRevokeFailure;
    if (failure != null) {
      nextRevokeFailure = null;
      throw failure;
    }
    final id = events[eventId];
    final p = id == null ? null : people[id];
    if (p == null) throw const NotFoundFailure();
    final tonight = p.todayMeal?.servedAt;
    final remaining = [
      for (final t in p.takenMeals)
        if (t != tonight) t,
    ];
    final undone = FastingPerson(
      id: p.id,
      firstName: p.firstName,
      lastName: p.lastName,
      cin: p.cin,
      phone: p.phone,
      comment: p.comment,
      singleMeal: p.singleMeal,
      familyMeal: p.familyMeal,
      lastTakenMeal: remaining.isEmpty ? null : remaining.first,
      takenMeals: remaining,
      mealTakenTodayFromServer: false,
      region: p.region,
    );
    people[p.id] = undone;
    return undone;
  }
```

5. In `testOverrides`, add this entry to the returned list:

```dart
  deviceIdProvider.overrideWith((ref) async => 'inst-test'),
```

- [ ] **Step 7: Run the tests**

Run Flutter with `test/data test/core/device_id_test.dart`. Expected: PASS. Then run `flutter test` (all) and `flutter analyze`. Expected: PASS with no analyzer errors. The callers still compile, because the new parameters are optional.

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/lib apps/mobile/test
git commit -m "feat(mobile): send clientEventId and device ID with confirms, undo call, 15 s mutation timeout

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 7: Scanner: idempotent confirm, "Sending… slow connection", one automatic retry

**Files:**
- Modify: `apps/mobile/lib/features/scan/presentation/scan_controller.dart` (full replacement below)
- Modify: `apps/mobile/lib/features/scan/presentation/scan_result_panel.dart`
- Modify: `apps/mobile/lib/l10n/app_en.arb`, `app_fr.arb`, `app_ar.arb` (+ regenerated `app_localizations*.dart`)
- Modify: `apps/mobile/test/presentation/scan_navigation_test.dart` (one pump duration)
- Test: `apps/mobile/test/presentation/scan_controller_test.dart`, `apps/mobile/test/presentation/scan_result_panel_2a_test.dart`

**Interfaces:**
- Consumes: Task 6's `confirmMeal(..., clientEventId, deviceId)`, `deviceIdProvider` and `newUuidV4()`; Task 5's `MealAlreadyTakenFailure.servedByName` and `FastingPerson.todayMealAt`.
- Produces:
  - `ScanTimings { slowAfter, autoRetryAfter, undoWindow }` and `scanTimingsProvider`.
  - `ScanConfirming(person, {required String clientEventId, bool noCard, bool slow})`.
  - `ScanFailed(..., {String? clientEventId})`.
  - `ScanAlreadyTaken(person, takenAt, {String? servedByName})`.
  - `ScanConfirmed` now lasts `undoWindow` (5 s) instead of 1.6 s. The "own confirmation" guess (`_ownConfirmationWindow` and `_uncertain*`) is removed.
  - The localization key `sendingSlow`.

- [ ] **Step 1: Write the failing controller tests**

In `apps/mobile/test/presentation/scan_controller_test.dart`, add `import 'package:iftar_mobile/features/people/domain/meal_event.dart';` and this group at the end of `main()`:

```dart
  group('spec 2A: safe confirm on a bad connection', () {
    late ProviderContainer fast;
    ScanController c() => fast.read(scanControllerProvider.notifier);
    ScanState s() => fast.read(scanControllerProvider);
    Future<void> wait(int ms) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    setUp(() async {
      fast = ProviderContainer.test(
        overrides: [
          ...testOverrides(repo, clock: () => now),
          scanTimingsProvider.overrideWithValue(
            const ScanTimings(
              slowAfter: Duration(milliseconds: 20),
              autoRetryAfter: Duration(milliseconds: 20),
              undoWindow: Duration(milliseconds: 50),
            ),
          ),
        ],
      );
      fast.listen(scanControllerProvider, (_, _) {});
      await fast.read(authControllerProvider.future);
    });

    test('each confirm sends a new clientEventId and the device ID', () async {
      repo.people[103] = person(103, first: 'Hedi', last: 'Jlassi');
      await c().onDetected('101');
      await c().confirm();
      final first = repo.lastClientEventId;
      expect(first, isNotNull);
      expect(repo.lastDeviceId, 'inst-test');

      await c().onDetected('103');
      await c().confirm();
      expect(repo.lastClientEventId, isNot(first));
    });

    test('a manual retry reuses the clientEventId of the failed confirm', () async {
      await c().onDetected('101');
      repo.nextConfirmFailure = const ServerFailure(statusCode: 502);
      await c().confirm();
      final id = repo.lastClientEventId;
      await c().retry();
      expect(repo.lastClientEventId, id);
      expect(s().status, isA<ScanConfirmed>());
    });

    test('a lost response, then retry: confirmed once, never "already served"', () async {
      await c().onDetected('101');
      repo
        ..nextConfirmFailure = const ServerFailure(statusCode: 502)
        ..applyThenFailConfirm = true; // recorded; the answer was lost
      await c().confirm();
      expect(s().status, isA<ScanFailed>());
      await c().retry();
      expect(s().status, isA<ScanConfirmed>());
      expect(s().servedCount, 1);
      expect(repo.people[101]!.takenMeals, hasLength(1));
    });

    test('a slow confirm says so after slowAfter, then confirms', () async {
      await c().onDetected('101');
      final gate = Completer<void>();
      repo.confirmGate = gate;
      final pending = c().confirm();
      await wait(5);
      expect((s().status as ScanConfirming).slow, isFalse);
      await wait(40);
      expect((s().status as ScanConfirming).slow, isTrue);
      gate.complete();
      await pending;
      expect(s().status, isA<ScanConfirmed>());
    });

    test('a network failure is retried once automatically, with the same ID', () async {
      await c().onDetected('101');
      repo.nextConfirmFailure = const NetworkFailure();
      await c().confirm();
      final id = repo.lastClientEventId;
      expect(s().status, isA<ScanFailed>());
      await wait(60);
      expect(repo.confirmCalls, 2);
      expect(repo.lastClientEventId, id);
      expect(s().status, isA<ScanConfirmed>());
    });

    test('the automatic retry happens only once', () async {
      await c().onDetected('101');
      repo.nextConfirmFailure = const TimeoutFailure();
      await c().confirm();
      repo.nextConfirmFailure = const TimeoutFailure(); // the retry fails too
      await wait(60);
      expect(repo.confirmCalls, 2);
      await wait(60);
      expect(repo.confirmCalls, 2);
      expect((s().status as ScanFailed).duringConfirm, isTrue);
    });

    test('Skip cancels the automatic retry', () async {
      await c().onDetected('101');
      repo.nextConfirmFailure = const NetworkFailure();
      await c().confirm();
      c().scanNext();
      await wait(60);
      expect(repo.confirmCalls, 1);
      expect(s().status, isA<ScanIdle>());
    });

    test('a server error is not retried automatically', () async {
      await c().onDetected('101');
      repo.nextConfirmFailure = const ServerFailure(statusCode: 500);
      await c().confirm();
      await wait(60);
      expect(repo.confirmCalls, 1);
    });

    test('"already served" says by whom', () async {
      repo.people[101] = person(
        101,
        takenToday: true,
        todayMeal: MealEvent(
          eventId: 'x',
          servedAt: testNow,
          servedByName: 'Sami',
        ),
      );
      await c().onDetected('101');
      expect((s().status as ScanAlreadyTaken).servedByName, 'Sami');
    });

    test('Confirmed stays for the undo window, then the camera view clears', () async {
      await c().onDetected('101');
      await c().confirm();
      expect(s().status, isA<ScanConfirmed>());
      await wait(80);
      expect(s().status, isA<ScanIdle>());
    });
  });
```

- [ ] **Step 2: Run them to see them fail**

Run Flutter with `test/presentation/scan_controller_test.dart`. Expected: compile errors (`scanTimingsProvider`, `ScanTimings`, `slow` and `servedByName` don't exist yet).

- [ ] **Step 3: Replace the scan controller**

Replace the whole of `apps/mobile/lib/features/scan/presentation/scan_controller.dart` with:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/storage/device_id.dart';
import '../../../core/utils/uuid.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../people/data/people_repository.dart';
import '../../people/domain/fasting_person.dart';
import '../../people/presentation/people_controller.dart';
import '../domain/qr_payload.dart';

/// The scan → identify → validate → confirm → result workflow.
sealed class ScanStatus {
  const ScanStatus();
}

/// Camera live, waiting for a card.
final class ScanIdle extends ScanStatus {
  const ScanIdle();
}

/// Not on this phone yet: only the ID is known while the server answers.
final class ScanLookingUp extends ScanStatus {
  const ScanLookingUp(this.personId, {this.noCard = false});
  final int personId;
  final bool noCard;
}

/// On this phone: name and meals show now while tonight's status is
/// checked with the server (spec §6.3). Display only, never a verdict.
final class ScanIdentifying extends ScanStatus {
  const ScanIdentifying(this.person, {this.noCard = false});
  final FastingPerson person;
  final bool noCard;
}

/// The code is not a person ID.
final class ScanInvalidCode extends ScanStatus {
  const ScanInvalidCode(this.raw);
  final String raw;
}

/// Valid ID, but nobody with it in the volunteer's region.
final class ScanNotFound extends ScanStatus {
  const ScanNotFound(this.personId);
  final int personId;
}

/// Eligible: has not collected today. Holds pending phone/comment edits.
final class ScanReady extends ScanStatus {
  const ScanReady(this.person, {this.phone, this.comment, this.noCard = false});
  final FastingPerson person;
  final String? phone;
  final String? comment;

  /// Found without a card: the volunteer checks the CIN's last digits.
  final bool noCard;
}

final class ScanConfirming extends ScanStatus {
  const ScanConfirming(
    this.person, {
    required this.clientEventId,
    this.noCard = false,
    this.slow = false,
  });
  final FastingPerson person;

  /// Sent with the confirm. Every retry of this confirm reuses it, so the
  /// server can never record it twice (spec 2A §5.1).
  final String clientEventId;
  final bool noCard;

  /// No answer after [ScanTimings.slowAfter]: "Sending… slow connection".
  final bool slow;
}

final class ScanConfirmed extends ScanStatus {
  const ScanConfirmed(this.person);
  final FastingPerson person;
}

/// Already collected today — do not serve again.
final class ScanAlreadyTaken extends ScanStatus {
  const ScanAlreadyTaken(this.person, this.takenAt, {this.servedByName});
  final FastingPerson person;
  final DateTime? takenAt;

  /// Who served it, when the server said (spec 2A §5.3).
  final String? servedByName;
}

/// Network/server error during lookup or confirmation; can be retried.
final class ScanFailed extends ScanStatus {
  const ScanFailed(
    this.failure, {
    required this.personId,
    this.person,
    this.pendingPhone,
    this.pendingComment,
    this.noCard = false,
    this.clientEventId,
  });
  final AppFailure failure;
  final int personId;

  /// Set when the failure happened while confirming this person.
  final FastingPerson? person;
  final String? pendingPhone;
  final String? pendingComment;

  /// The CIN check still applies when this is retried.
  final bool noCard;

  /// The failed confirm's ID; Retry sends it again.
  final String? clientEventId;

  bool get duringConfirm => person != null;
}

class ScanState {
  const ScanState({
    this.status = const ScanIdle(),
    this.servedCount = 0,
    this.singleMeals = 0,
    this.familyMeals = 0,
  });

  final ScanStatus status;

  /// Meals confirmed from this device since the scanner was opened.
  final int servedCount;

  /// Meals handed over this session, for the closing summary.
  final int singleMeals;
  final int familyMeals;

  /// Whether a new camera detection should be processed right now.
  /// Busy or pending-decision states ignore the camera, so a volunteer never
  /// loses an unconfirmed person by accidentally scanning another card.
  bool get acceptsScans => switch (status) {
    ScanIdle() ||
    ScanInvalidCode() ||
    ScanNotFound() ||
    ScanAlreadyTaken() ||
    ScanConfirmed() => true,
    ScanFailed(:final duringConfirm) => !duringConfirm,
    ScanLookingUp() ||
    ScanIdentifying() ||
    ScanReady() ||
    ScanConfirming() => false,
  };

  ScanState copyWith({
    ScanStatus? status,
    int? servedCount,
    int? singleMeals,
    int? familyMeals,
  }) => ScanState(
    status: status ?? this.status,
    servedCount: servedCount ?? this.servedCount,
    singleMeals: singleMeals ?? this.singleMeals,
    familyMeals: familyMeals ?? this.familyMeals,
  );
}

/// Delays of the confirm flow (spec 2A §5.1, §5.2). Tests shorten them.
class ScanTimings {
  const ScanTimings({
    this.slowAfter = const Duration(seconds: 2),
    this.autoRetryAfter = const Duration(seconds: 3),
    this.undoWindow = const Duration(seconds: 5),
  });

  /// No answer yet: say "Sending… slow connection".
  final Duration slowAfter;

  /// A network or timeout failure is retried once, this long after.
  final Duration autoRetryAfter;

  /// How long the Confirmed band stays (with Undo) before the view clears.
  final Duration undoWindow;
}

final scanTimingsProvider = Provider<ScanTimings>((_) => const ScanTimings());

class ScanController extends Notifier<ScanState> {
  /// A card held in front of the camera is read many times per second; the
  /// same code is ignored while it keeps being seen within this window.
  static const duplicateWindow = Duration(seconds: 4);

  String? _lastRaw;
  DateTime? _lastSeenAt;
  Timer? _resumeTimer;
  Timer? _slowTimer;
  Timer? _autoRetryTimer;

  /// The confirm already retried automatically. One automatic retry per
  /// confirm; after that the volunteer decides.
  String? _autoRetriedEventId;

  DateTime _now() => ref.read(clockProvider)();

  ScanTimings get _timings => ref.read(scanTimingsProvider);

  @override
  ScanState build() {
    ref.onDispose(() {
      _resumeTimer?.cancel();
      _slowTimer?.cancel();
      _autoRetryTimer?.cancel();
    });
    return const ScanState();
  }

  /// Camera callback.
  Future<void> onDetected(String? raw) async {
    if (!state.acceptsScans || raw == null) return;
    final now = _now();
    final isRepeat =
        raw == _lastRaw &&
        _lastSeenAt != null &&
        now.difference(_lastSeenAt!) < duplicateWindow;
    _lastSeenAt = now;
    if (isRepeat) return;
    _lastRaw = raw;
    await _handle(raw);
  }

  bool get _busy => switch (state.status) {
    ScanLookingUp() || ScanIdentifying() || ScanConfirming() => true,
    _ => false,
  };

  /// Looks up an ID given as text, bypassing the duplicate-scan filter. No
  /// screen calls it today (Find covers damaged cards); it is the entry point
  /// the controller tests drive.
  Future<void> submitManual(String input) async {
    if (_busy) return;
    // A failed confirm must be resolved (retry or skip) first.
    if (state.status case ScanFailed(duringConfirm: true)) return;
    _lastRaw = input.trim();
    _lastSeenAt = _now();
    await _handle(input);
  }

  /// "Find someone without a card" (spec §4.7): same flow, plus the CIN check.
  Future<void> pickWithoutCard(int personId) async {
    if (_busy) return;
    // A failed confirm must be resolved (retry or skip) first.
    if (state.status case ScanFailed(duringConfirm: true)) return;
    _resumeTimer?.cancel();
    _lastRaw = '$personId';
    _lastSeenAt = _now();
    await _lookup(personId, noCard: true);
  }

  /// Back from another screen (Details, the registration form): looks the
  /// shown person up again when something there may have changed the answer.
  /// A pending person is only re-checked when the list says they were served
  /// meanwhile, so contact edits made here survive a look at Details. An
  /// unknown card is looked up again (it may have just been registered).
  Future<void> refreshCurrent() async {
    switch (state.status) {
      case ScanReady(:final person, :final noCard):
        if (_cached(person.id)?.isMealTakenToday(_now()) != true) return;
        _resumeTimer?.cancel();
        await _lookup(person.id, noCard: noCard);
      case ScanNotFound(:final personId):
        _resumeTimer?.cancel();
        await _lookup(personId);
      default:
        return;
    }
  }

  Future<void> _handle(String raw) async {
    _resumeTimer?.cancel();
    switch (QrPayload.parse(raw)) {
      case InvalidQr(:final raw):
        _set(ScanInvalidCode(raw));
      case PersonQr(:final personId):
        await _lookup(personId);
    }
  }

  Future<void> _lookup(int personId, {bool noCard = false}) async {
    final cached = _cached(personId);
    _set(
      cached == null
          ? ScanLookingUp(personId, noCard: noCard)
          : ScanIdentifying(cached, noCard: noCard),
    );
    try {
      final region = requireRegion(ref);
      final person = await ref
          .read(peopleRepositoryProvider)
          .get(region.id, personId);
      if (!_stillLookingUp(personId)) return;
      ref.read(peopleListProvider.notifier).upsert(person);
      // The verdict always comes from the server response.
      final meal = person.todayMealAt(_now());
      _set(
        person.isMealTakenToday(_now())
            ? ScanAlreadyTaken(
                person,
                meal?.servedAt ?? person.lastTakenMeal,
                servedByName: meal?.servedByName,
              )
            : ScanReady(person, noCard: noCard),
      );
    } on NotFoundFailure {
      if (_stillLookingUp(personId)) _set(ScanNotFound(personId));
    } catch (e) {
      if (_stillLookingUp(personId)) {
        _set(
          ScanFailed(toAppFailure(e), personId: personId, noCard: noCard),
        );
      }
    }
  }

  FastingPerson? _cached(int id) {
    for (final p
        in ref.read(peopleListProvider).value ?? const <FastingPerson>[]) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool _stillLookingUp(int id) =>
      ref.mounted &&
      switch (state.status) {
        ScanLookingUp(:final personId) => personId == id,
        ScanIdentifying(:final person) => person.id == id,
        _ => false,
      };

  /// Pending phone/comment edits, sent with the confirmation.
  void editContact({required String phone, required String comment}) {
    if (state.status case ScanReady(:final person, :final noCard)) {
      _set(ScanReady(person, phone: phone, comment: comment, noCard: noCard));
    }
  }

  /// "Confirm & scan next", and Retry after a failed confirm.
  Future<void> confirm() async {
    final (person, phone, comment, noCard, retryOf) = switch (state.status) {
      ScanReady(:final person, :final phone, :final comment, :final noCard) => (
        person,
        phone,
        comment,
        noCard,
        null,
      ),
      ScanFailed(
        :final person?,
        :final pendingPhone,
        :final pendingComment,
        :final noCard,
        :final clientEventId,
      ) =>
        (person, pendingPhone, pendingComment, noCard, clientEventId),
      _ => (null, null, null, false, null),
    };
    if (person == null) return;

    _autoRetryTimer?.cancel();
    // A retry repeats the same confirm; a new tap is a new one.
    final eventId = retryOf ?? newUuidV4();
    _set(ScanConfirming(person, clientEventId: eventId, noCard: noCard));
    _slowTimer?.cancel();
    _slowTimer = Timer(_timings.slowAfter, () {
      if (!ref.mounted) return;
      if (state.status case ScanConfirming(
        clientEventId: final id,
        :final person,
        :final noCard,
      ) when id == eventId) {
        _set(
          ScanConfirming(
            person,
            clientEventId: eventId,
            noCard: noCard,
            slow: true,
          ),
        );
      }
    });

    try {
      final region = requireRegion(ref);
      final deviceId = await ref.read(deviceIdProvider.future);
      final updated = await ref
          .read(peopleRepositoryProvider)
          .confirmMeal(
            region.id,
            person.id,
            phone: phone,
            comment: comment,
            clientEventId: eventId,
            deviceId: deviceId,
          );
      _slowTimer?.cancel();
      if (!ref.mounted) return;
      _onConfirmed(updated);
    } on MealAlreadyTakenFailure catch (e) {
      _slowTimer?.cancel();
      if (!ref.mounted) return;
      // The server answers a retry of our own confirm with 200, so a 409 is
      // always a real earlier meal: another phone, or before a Skip.
      _set(ScanAlreadyTaken(person, e.takenAt, servedByName: e.servedByName));
    } catch (e) {
      _slowTimer?.cancel();
      if (!ref.mounted) return;
      final failure = toAppFailure(e);
      _set(
        ScanFailed(
          failure,
          personId: person.id,
          person: person,
          pendingPhone: phone,
          pendingComment: comment,
          noCard: noCard,
          clientEventId: eventId,
        ),
      );
      final network = failure is NetworkFailure || failure is TimeoutFailure;
      if (network && _autoRetriedEventId != eventId) {
        _autoRetriedEventId = eventId;
        _autoRetryTimer = Timer(_timings.autoRetryAfter, () {
          if (!ref.mounted) return;
          if (state.status case ScanFailed(
            clientEventId: final id,
          ) when id == eventId) {
            unawaited(confirm());
          }
        });
      }
    }
  }

  void _onConfirmed(FastingPerson person) {
    ref.read(peopleListProvider.notifier).upsert(person);
    state = state.copyWith(
      status: ScanConfirmed(person),
      servedCount: state.servedCount + 1,
      singleMeals: state.singleMeals + person.singleMeal,
      familyMeals: state.familyMeals + person.familyMeal,
    );
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_timings.undoWindow, () {
      if (ref.mounted && state.status is ScanConfirmed) {
        _set(const ScanIdle());
      }
    });
  }

  Future<void> retry() async {
    final status = state.status;
    if (status is! ScanFailed) return;
    if (status.duringConfirm) {
      await confirm();
    } else {
      await _lookup(status.personId, noCard: status.noCard);
    }
  }

  /// Back to the camera ("Scan next" / "Skip"). The card that is probably
  /// still in front of the lens is not re-read immediately.
  void scanNext() {
    _resumeTimer?.cancel();
    _autoRetryTimer?.cancel();
    _lastSeenAt = _now();
    _set(const ScanIdle());
  }

  void _set(ScanStatus status) => state = state.copyWith(status: status);
}

final scanControllerProvider =
    NotifierProvider.autoDispose<ScanController, ScanState>(ScanController.new);
```

- [ ] **Step 4: Show "Sending… slow connection" in the panel**

In `apps/mobile/lib/features/scan/presentation/scan_result_panel.dart`:

1. Replace the `ScanConfirming` case with:

```dart
      case ScanConfirming(:final person, :final noCard, :final slow):
        return _ready(
          context,
          controller,
          person,
          phone: person.phone,
          comment: person.comment,
          noCard: noCard,
          busy: true,
          slow: slow,
        );
```

2. Add `bool slow = false,` to `_ready`'s named parameters, after `required bool busy,`. Then replace its `band:` argument with:

```dart
      band: slow
          ? _Band(
              color: AppPalette.waitBand,
              seal: Seal(SealKind.checking, semanticLabel: l.sealChecking),
              title: l.sendingSlow,
              subtitle: l.dontHandOverYet,
              small: true,
            )
          : _Band(
              color: c.serveBand,
              seal: Seal(SealKind.serve, semanticLabel: l.sealServe),
              title: MealStatusWords.notTaken,
              subtitle: l.notServedTonight,
            ),
```

- [ ] **Step 5: Add the string in three languages**

Add after `"confirming"` in each ARB file:
- `app_en.arb`: `"sendingSlow": "Sending… slow connection",`
- `app_fr.arb`: `"sendingSlow": "Envoi… connexion lente",`
- `app_ar.arb`: `"sendingSlow": "جارٍ الإرسال… الاتصال بطيء",`

The `flutter gen-l10n` in the run command regenerates `app_localizations*.dart`. These files are tracked: commit them.

- [ ] **Step 6: Panel test**

Create `apps/mobile/test/presentation/scan_result_panel_2a_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_result_panel.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

Widget panel(ScanStatus status, FakePeopleRepository repo) => localizedApp(
  Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: ScanResultPanel(status: status, onFindWithoutCard: () {}),
    ),
  ),
  overrides: testOverrides(repo),
);

void main() {
  testWidgets('a slow confirm says so and keeps Confirm disabled', (tester) async {
    final repo = FakePeopleRepository([person(101)]);
    await tester.pumpWidget(
      panel(ScanConfirming(person(101), clientEventId: 'c', slow: true), repo),
    );
    await tester.pump();
    expect(find.text(en.sendingSlow), findsOneWidget);
    expect(find.text(en.dontHandOverYet), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(en.confirming),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
```

- [ ] **Step 7: Adjust the one test that waited for the old 1.6 s hold**

In `apps/mobile/test/presentation/scan_navigation_test.dart`, replace

```dart
      await tester.pump(const Duration(seconds: 2)); // confirmed hold ends
```

with

```dart
      await tester.pump(const Duration(seconds: 6)); // undo window ends
```

- [ ] **Step 8: Run the tests**

Run Flutter with `test/presentation/scan_controller_test.dart test/presentation/scan_result_panel_2a_test.dart`. Expected: PASS. Then run `flutter test` (all) and `flutter analyze`. Expected: PASS.

The only expected fallout: a widget test that waits less than 5 s for the Confirmed band to go away. Raise its pump to 6 s. Find such tests with `grep -rn "ScanConfirmed\|servedLine" apps/mobile/test/presentation`.

- [ ] **Step 9: Commit**

```bash
git add apps/mobile/lib apps/mobile/test
git commit -m "feat(mobile): idempotent confirm, slow-connection notice, one automatic retry; served-by on already served

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Scanner Undo ("Undo · 5")

**Files:**
- Modify: `apps/mobile/lib/features/scan/presentation/scan_controller.dart`
- Modify: `apps/mobile/lib/features/scan/presentation/scan_result_panel.dart`
- Modify: `apps/mobile/lib/features/scan/presentation/scan_page.dart`
- Modify: the 3 ARB files (+ regenerated `app_localizations*.dart`)
- Test: `apps/mobile/test/presentation/scan_controller_test.dart`, `apps/mobile/test/presentation/scan_result_panel_2a_test.dart`

**Interfaces:**
- Consumes: Task 6's `revokeMeal` and `UndoRefusedFailure`; Task 7's `ScanTimings.undoWindow` and `ScanAlreadyTaken.servedByName`; Task 5's `MealEvent`.
- Produces:
  - `ScanConfirmed(person, {bool undoing})`.
  - `enum ScanNoticeKind { undone, undoFailed, undoTooLate, undoNeedsConnection }`, `class ScanNotice(kind, {name})` and `ScanState.notice`.
  - `ScanController.undo()` and `ScanController.undoFromHistory(FastingPerson person, MealEvent meal)`.
  - The localization keys `undoCountdown(int seconds)`, `undone(String name)`, `undoFailed`, `undoTooLate`, `undoNeedsConnection` and `servedAtBy(String time, String name)`.

- [ ] **Step 1: Write the failing tests**

Add to the `'spec 2A: safe confirm on a bad connection'` group in `scan_controller_test.dart`:

```dart
    test('Undo reverses the meal, the count and the hand-over totals', () async {
      await c().onDetected('101');
      await c().confirm();
      expect(s().servedCount, 1);
      await c().undo();
      expect(repo.revokeCalls, 1);
      expect(s().status, isA<ScanIdle>());
      expect(s().servedCount, 0);
      expect(s().singleMeals, 0);
      expect(s().familyMeals, 0);
      expect(s().notice!.kind, ScanNoticeKind.undone);
      expect(s().notice!.name, 'Najwa Chalbi');
      expect(repo.people[101]!.isMealTakenToday(testNow), isFalse);
    });

    test('cards are ignored while Undo is in flight', () async {
      await c().onDetected('101');
      await c().confirm();
      final gate = Completer<void>();
      repo.revokeGate = gate;
      final pending = c().undo();
      expect((s().status as ScanConfirmed).undoing, isTrue);
      expect(s().acceptsScans, isFalse);
      gate.complete();
      await pending;
    });

    test('too late: says so, and the meal stays', () async {
      await c().onDetected('101');
      await c().confirm();
      repo.nextRevokeFailure = const UndoRefusedFailure(
        UndoRefusedFailure.windowExpired,
      );
      await c().undo();
      expect(s().notice!.kind, ScanNoticeKind.undoTooLate);
      expect(s().servedCount, 1);
    });

    test('no connection: says Undo needs one', () async {
      await c().onDetected('101');
      await c().confirm();
      repo.nextRevokeFailure = const NetworkFailure();
      await c().undo();
      expect(s().notice!.kind, ScanNoticeKind.undoNeedsConnection);
    });

    test('Undo from History on an already-served person, then they can be served', () async {
      await c().onDetected('101');
      await c().confirm();
      c().scanNext();
      now = now.add(const Duration(seconds: 10));
      await c().onDetected('101');
      final taken = s().status as ScanAlreadyTaken;
      await c().undoFromHistory(taken.person, taken.person.todayMeal!);
      expect(s().notice!.kind, ScanNoticeKind.undone);
      expect(s().status, isA<ScanReady>());
    });
```

Add to `main()` of `scan_result_panel_2a_test.dart`, with `import 'package:iftar_mobile/features/people/domain/meal_event.dart';`:

```dart
  testWidgets('Confirmed offers Undo with a countdown', (tester) async {
    final repo = FakePeopleRepository([person(101)]);
    final served = person(
      101,
      takenToday: true,
      todayMeal: MealEvent(
        eventId: 'e1',
        servedAt: testNow,
        servedById: testUser.id,
      ),
    );
    await tester.pumpWidget(panel(ScanConfirmed(served), repo));
    await tester.pump();
    expect(find.text(en.undoCountdown(5)), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(en.undoCountdown(4)), findsOneWidget);
  });

  testWidgets('no Undo when the server sent no meal ID (older backend)', (tester) async {
    final repo = FakePeopleRepository([person(101)]);
    await tester.pumpWidget(
      panel(ScanConfirmed(person(101, takenToday: true)), repo),
    );
    await tester.pump();
    expect(find.byIcon(Icons.undo_rounded), findsNothing);
  });

  testWidgets('already served says by whom', (tester) async {
    final repo = FakePeopleRepository([person(101)]);
    await tester.pumpWidget(
      panel(
        ScanAlreadyTaken(
          person(101, takenToday: true),
          testNow,
          servedByName: 'Sami',
        ),
        repo,
      ),
    );
    await tester.pump();
    expect(find.textContaining('Sami'), findsOneWidget);
  });
```

- [ ] **Step 2: Run them to see them fail**

Run Flutter with `test/presentation/scan_controller_test.dart test/presentation/scan_result_panel_2a_test.dart`. Expected: compile errors (`undo`, `undoing`, `notice` and `undoCountdown` don't exist yet).

- [ ] **Step 3: Controller: undoing, notices, undo**

In `scan_controller.dart`:

1. Add `import '../../people/domain/meal_event.dart';`.
2. Replace `ScanConfirmed` with:

```dart
final class ScanConfirmed extends ScanStatus {
  const ScanConfirmed(this.person, {this.undoing = false});
  final FastingPerson person;

  /// Undo was tapped and the server hasn't answered yet.
  final bool undoing;
}
```

3. Add after `ScanFailed`:

```dart
enum ScanNoticeKind { undone, undoFailed, undoTooLate, undoNeedsConnection }

/// A one-off message for the volunteer, shown as a snackbar. Every notice is
/// a new object, so the same message twice is shown twice.
class ScanNotice {
  ScanNotice(this.kind, {this.name});
  final ScanNoticeKind kind;

  /// The person, for "Undone. {name} is not marked as served."
  final String? name;
}
```

4. In `ScanState`:
   - Add the constructor parameter `this.notice,` and the field `/// The latest message for the volunteer (see [ScanNotice]). final ScanNotice? notice;`.
   - In `acceptsScans`, remove `ScanConfirmed()` from the `=> true` group and add the case `ScanConfirmed(:final undoing) => !undoing,`.
   - In `copyWith`, add the parameter `ScanNotice? notice` and pass `notice: notice ?? this.notice,`.

5. Add to `ScanController`, after `_onConfirmed`:

```dart
  /// "Undo · 5" on the Confirmed band (spec 2A §5.2).
  Future<void> undo() async {
    final status = state.status;
    if (status is! ScanConfirmed || status.undoing) return;
    final meal = status.person.todayMeal;
    if (meal == null) return;
    _resumeTimer?.cancel();
    _set(ScanConfirmed(status.person, undoing: true));
    final notice = await _revoke(meal.eventId, status.person);
    if (!ref.mounted) return;
    final undone = notice.kind == ScanNoticeKind.undone;
    final p = status.person;
    state = state.copyWith(
      status: const ScanIdle(),
      notice: notice,
      servedCount: undone ? state.servedCount - 1 : null,
      singleMeals: undone ? state.singleMeals - p.singleMeal : null,
      familyMeals: undone ? state.familyMeals - p.familyMeal : null,
    );
    // The card still in front of the lens is not re-read at once.
    _lastSeenAt = _now();
  }

  /// History → "Undo tonight's meal" on an Already-served sheet: undo, then
  /// look the person up again so the sheet shows the new answer.
  Future<void> undoFromHistory(FastingPerson person, MealEvent meal) async {
    if (state.status is! ScanAlreadyTaken) return;
    final notice = await _revoke(meal.eventId, person);
    if (!ref.mounted) return;
    state = state.copyWith(notice: notice);
    if (notice.kind == ScanNoticeKind.undone) await _lookup(person.id);
  }

  Future<ScanNotice> _revoke(String eventId, FastingPerson person) async {
    try {
      final updated = await ref
          .read(peopleRepositoryProvider)
          .revokeMeal(eventId);
      if (ref.mounted) ref.read(peopleListProvider.notifier).upsert(updated);
      return ScanNotice(ScanNoticeKind.undone, name: person.fullName);
    } on UndoRefusedFailure catch (e) {
      return ScanNotice(
        e.tooLate ? ScanNoticeKind.undoTooLate : ScanNoticeKind.undoFailed,
      );
    } on NetworkFailure {
      return ScanNotice(ScanNoticeKind.undoNeedsConnection);
    } on TimeoutFailure {
      return ScanNotice(ScanNoticeKind.undoNeedsConnection);
    } on Object {
      return ScanNotice(ScanNoticeKind.undoFailed);
    }
  }
```

- [ ] **Step 4: Panel: Undo button, served-by line**

In `scan_result_panel.dart`:

1. Add `import 'dart:async';` at the top.
2. Replace the `ScanConfirmed` case with:

```dart
      case ScanConfirmed(:final person, :final undoing):
        return _DoneBand(
          person: person,
          undoing: undoing,
          undoWindow: ref.read(scanTimingsProvider).undoWindow,
          // No meal ID (older backend): nothing the server could undo.
          onUndo: person.todayMeal == null ? null : controller.undo,
        );
```

3. In the `ScanAlreadyTaken` case, destructure `:final servedByName` as well. Then make the `body:` list:

```dart
          body: [
            if (time != null && servedByName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l.servedAtBy(time, isolate(servedByName)),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.clayInk,
                  ),
                ),
              ),
            Text(
              time == null ? l.alreadyServedNoteNoTime : l.alreadyServedNote(time),
              style: TextStyle(fontSize: 13, color: c.clayInk),
            ),
          ],
```

4. Change `_DoneBand`'s constructor and fields to:

```dart
  const _DoneBand({
    required this.person,
    required this.undoing,
    required this.undoWindow,
    required this.onUndo,
  });

  final FastingPerson person;
  final bool undoing;
  final Duration undoWindow;

  /// Null when this meal can't be undone from here.
  final VoidCallback? onUndo;
```

In `_DoneBand`'s inner `Column`, after the `if (l.blessingMeaning.isNotEmpty) …` entry, add:

```dart
                        if (onUndo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _UndoButton(
                              window: undoWindow,
                              undoing: undoing,
                              onPressed: onUndo!,
                            ),
                          ),
```

5. Add after `_DoneBand`:

```dart
/// "Undo · 5", counting down while the band is shown (spec 2A §5.2).
class _UndoButton extends StatefulWidget {
  const _UndoButton({
    required this.window,
    required this.undoing,
    required this.onPressed,
  });

  final Duration window;
  final bool undoing;
  final VoidCallback onPressed;

  @override
  State<_UndoButton> createState() => _UndoButtonState();
}

class _UndoButtonState extends State<_UndoButton> {
  late int _left = widget.window.inSeconds.clamp(1, 60);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left > 1) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
        minimumSize: const Size(0, 44),
      ),
      onPressed: widget.undoing ? null : widget.onPressed,
      icon: widget.undoing
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.undo_rounded),
      label: Text(l.undoCountdown(_left)),
    );
  }
}
```

- [ ] **Step 5: Page: show notices; Undo doesn't buzz again**

In `scan_page.dart`:

1. Add `import '../../../core/utils/formatters.dart';` and import the file that defines `showAppSnackBar`. Find it with `grep -rn "showAppSnackBar(" apps/mobile/lib/core`; it's expected to be `../../../core/widgets/state_views.dart`.
2. Replace `_sameVerdict` with:

```dart
  /// Only "ready" (contact edits) and "confirmed" (Undo in flight) are
  /// re-created in place; every other change is news worth a buzz.
  static bool _sameVerdict(ScanStatus a, ScanStatus b) =>
      (a is ScanReady && b is ScanReady && a.person.id == b.person.id) ||
      (a is ScanConfirmed && b is ScanConfirmed && a.person.id == b.person.id);
```

3. In `build`, after the existing `ref.listen(...)`, add:

```dart
    ref.listen(scanControllerProvider.select((s) => s.notice), (prev, next) {
      if (next == null || identical(prev, next)) return;
      final l = AppLocalizations.of(context);
      showAppSnackBar(
        context,
        switch (next.kind) {
          ScanNoticeKind.undone => l.undone(isolate(next.name ?? '')),
          ScanNoticeKind.undoFailed => l.undoFailed,
          ScanNoticeKind.undoTooLate => l.undoTooLate,
          ScanNoticeKind.undoNeedsConnection => l.undoNeedsConnection,
        },
        isError: next.kind != ScanNoticeKind.undone,
      );
    });
```

- [ ] **Step 6: Strings**

`app_en.arb`:

```json
  "undoCountdown": "Undo · {seconds}",
  "@undoCountdown": {"placeholders": {"seconds": {"type": "int"}}},
  "undone": "Undone. {name} is not marked as served.",
  "@undone": {"placeholders": {"name": {"type": "String"}}},
  "undoFailed": "Couldn’t undo. Try again from History.",
  "undoTooLate": "It’s too late to undo. Ask an admin.",
  "undoNeedsConnection": "Undo needs a connection. Try again from History.",
  "servedAtBy": "Served at {time} by {name}",
  "@servedAtBy": {"placeholders": {"time": {"type": "String"}, "name": {"type": "String"}}},
```

`app_fr.arb`:

```json
  "undoCountdown": "Annuler · {seconds}",
  "undone": "Annulé. {name} n’est plus marqué comme servi.",
  "undoFailed": "Impossible d’annuler. Réessayez depuis l’historique.",
  "undoTooLate": "Il est trop tard pour annuler. Demandez à un administrateur.",
  "undoNeedsConnection": "L’annulation nécessite une connexion. Réessayez depuis l’historique.",
  "servedAtBy": "Servi à {time} par {name}",
```

`app_ar.arb`:

```json
  "undoCountdown": "تراجع · {seconds}",
  "undone": "تم التراجع. {name} لم يعد مسجّلًا كمن استلم.",
  "undoFailed": "تعذّر التراجع. حاول مجددًا من السجل.",
  "undoTooLate": "فات وقت التراجع. اطلب ذلك من المشرف.",
  "undoNeedsConnection": "التراجع يحتاج إلى اتصال. حاول مجددًا من السجل.",
  "servedAtBy": "استلم على الساعة {time}، قدّمها {name}",
```

- [ ] **Step 7: Run the tests**

Run Flutter with `test/presentation/scan_controller_test.dart test/presentation/scan_result_panel_2a_test.dart test/l10n`. Expected: PASS. Then run `flutter test` (all) and `flutter analyze`. Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/lib apps/mobile/test
git commit -m "feat(mobile): Undo · 5 on the confirmed band, with undo notices; served-by on already served

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: History sheet Undo, served-by rows, retry-safe confirm on Details

**Files:**
- Modify: `apps/mobile/lib/features/people/presentation/person_widgets.dart` (`showMealHistory`)
- Modify: `apps/mobile/lib/features/people/presentation/people_controller.dart` (`PersonDetailsController`)
- Modify: `apps/mobile/lib/features/people/presentation/person_details_page.dart`
- Modify: `apps/mobile/lib/features/scan/presentation/scan_result_panel.dart` (the History link on Already served)
- Modify: the 3 ARB files (+ regenerated)
- Test: `apps/mobile/test/presentation/person_details_2a_test.dart`

**Interfaces:**
- Consumes: Task 5's `undoableMeal` and `MealEvent`; Task 6's `revokeMeal`, `deviceIdProvider` and `newUuidV4`; Task 8's `ScanController.undoFromHistory` and the `undone`, `undoFailed`, `undoTooLate` and `undoNeedsConnection` strings.
- Produces:
  - `showMealHistory(context, person, {MealEvent? undoable, Future<void> Function(MealEvent meal)? onUndo})`.
  - `PersonDetailsController.confirmMeal({phone, comment, clientEventId})` and `PersonDetailsController.undoMeal(MealEvent meal)`.
  - The localization keys `undoTonightsMeal` and `servedBy(String name)`.

- [ ] **Step 1: Write the failing tests**

Create `apps/mobile/test/presentation/person_details_2a_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/features/people/domain/meal_event.dart';
import 'package:iftar_mobile/features/people/presentation/person_details_page.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

void main() {
  Widget details(int id, FakePeopleRepository repo) => localizedApp(
    PersonDetailsPage(personId: id),
    overrides: testOverrides(repo),
  );

  testWidgets('a retried confirm from Details reuses its clientEventId', (tester) async {
    final repo = FakePeopleRepository([person(101)]);
    repo.nextConfirmFailure = const ServerFailure(statusCode: 502);
    await tester.pumpWidget(details(101, repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.confirmMeal));
    await tester.pumpAndSettle();
    final first = repo.lastClientEventId;
    await tester.tap(find.text(en.confirmMeal));
    await tester.pumpAndSettle();
    expect(repo.confirmCalls, 2);
    expect(repo.lastClientEventId, first);
  });

  testWidgets('History offers Undo for my meal tonight, and it works', (tester) async {
    final repo = FakePeopleRepository([person(101)]);
    await tester.pumpWidget(details(101, repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.confirmMeal));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.undoTonightsMeal));
    await tester.pumpAndSettle();

    expect(repo.revokeCalls, 1);
    expect(find.textContaining('Najwa Chalbi'), findsWidgets);
    expect(find.text(en.confirmMeal), findsOneWidget); // can be served again
  });

  testWidgets("History doesn't offer Undo for someone else's meal", (tester) async {
    final repo = FakePeopleRepository([
      person(
        102,
        takenToday: true,
        todayMeal: MealEvent(
          eventId: 'theirs',
          servedAt: testNow.subtract(const Duration(minutes: 2)),
          servedById: 99,
          servedByName: 'Sami',
        ),
      ),
    ]);
    await tester.pumpWidget(details(102, repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();
    expect(find.text(en.undoTonightsMeal), findsNothing);
  });

  testWidgets('History rows say who served', (tester) async {
    final servedAt = testNow.subtract(const Duration(minutes: 5));
    final repo = FakePeopleRepository([
      person(103, takenToday: true).copyWith(
        takenMeals: [servedAt],
        meals: [
          MealEvent(eventId: 'm', servedAt: servedAt, servedById: 99, servedByName: 'Sami'),
        ],
      ),
    ]);
    await tester.pumpWidget(details(103, repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sami'), findsOneWidget);
  });
}
```

If `en.confirmMeal` or the history icon isn't how `person_details_page.dart` labels them, read the file (the confirm button uses `l.confirmMeal`; the history button uses `Icons.history_rounded`) and match it.

- [ ] **Step 2: Run them to see them fail**

Run Flutter with `test/presentation/person_details_2a_test.dart`. Expected: FAIL. The retry sends a new ID, `undoTonightsMeal` doesn't exist, and no "Sami" appears.

- [ ] **Step 3: The History sheet**

In `person_widgets.dart`:

1. Add `import '../domain/meal_event.dart';`.
2. Change the signature to:

```dart
/// Bottom sheet: "List of taken meals for …" (Ionic modal on the badge).
/// With [undoable] and [onUndo], it offers "Undo tonight's meal" (spec 2A §5.2).
Future<void> showMealHistory(
  BuildContext context,
  FastingPerson person, {
  MealEvent? undoable,
  Future<void> Function(MealEvent meal)? onUndo,
}) {
```

3. Inside the `DraggableScrollableSheet` builder, right after `final l = AppLocalizations.of(context);`, add:

```dart
        // Who served each meal, matched by instant (single-person reads).
        final servedBy = <int, String>{
          for (final m in [...person.meals, ?person.todayMeal])
            if (m.isActive && m.servedByName != null)
              m.servedAt.millisecondsSinceEpoch: m.servedByName!,
        };
```

4. Replace the `if (i == 0) { return Padding(...); }` header item with:

```dart
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      l.mealHistoryTitle(isolate(person.fullName)),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (undoable != null && onUndo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(context);
                          onUndo(undoable);
                        },
                        icon: const Icon(Icons.undo_rounded),
                        label: Text(l.undoTonightsMeal),
                      ),
                    ),
                ],
              );
            }
```

5. In the meal row's `ListTile`, add:

```dart
              subtitle: switch (servedBy[date.millisecondsSinceEpoch]) {
                final name? => Text(l.servedBy(isolate(name))),
                null => null,
              },
```

6. The "no meals yet" early return only happens when `person.takenMeals.isEmpty`. A person can't have a meal to undo without a taken meal, so that branch stays as it is.

- [ ] **Step 4: `PersonDetailsController`**

In `people_controller.dart`, add these imports:

```dart
import '../../../core/storage/device_id.dart';
import '../domain/meal_event.dart';
```

Replace `PersonDetailsController.confirmMeal` with these two methods:

```dart
  /// Confirms today's meal. [clientEventId] must be reused when the same
  /// confirm is retried (spec 2A §5.1). On "already taken" the person is
  /// reloaded so the screen reflects the server state, and the failure is
  /// rethrown.
  Future<FastingPerson> confirmMeal({
    String? phone,
    String? comment,
    String? clientEventId,
  }) async {
    final region = requireRegion(ref);
    try {
      final updated = await ref
          .read(peopleRepositoryProvider)
          .confirmMeal(
            region.id,
            personId,
            phone: phone,
            comment: comment,
            clientEventId: clientEventId,
            deviceId: await ref.read(deviceIdProvider.future),
          );
      state = AsyncData(updated);
      ref.read(peopleListProvider.notifier).upsert(updated);
      return updated;
    } on MealAlreadyTakenFailure {
      final fresh = await ref
          .read(peopleRepositoryProvider)
          .get(region.id, personId);
      state = AsyncData(fresh);
      ref.read(peopleListProvider.notifier).upsert(fresh);
      rethrow;
    }
  }

  /// Undoes tonight's meal (spec 2A §4.2). Failures are rethrown.
  Future<FastingPerson> undoMeal(MealEvent meal) async {
    final updated = await ref
        .read(peopleRepositoryProvider)
        .revokeMeal(meal.eventId);
    state = AsyncData(updated);
    ref.read(peopleListProvider.notifier).upsert(updated);
    return updated;
  }
```

- [ ] **Step 5: The Details page**

In `person_details_page.dart`:

1. Add these imports:

```dart
import '../../../core/utils/uuid.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/meal_event.dart';
import '../domain/undo_rules.dart';
```

2. Add this field next to `bool _confirming = false;`:

```dart
  /// The ID of the confirm being attempted. Kept until it succeeds or the
  /// person turns out to be served, so a retry can't record a second meal.
  String? _pendingEventId;
```

3. In `_confirm`, pass `clientEventId: _pendingEventId ??= newUuidV4()` to `.confirmMeal(...)`. In the success branch, change `setState(() => _phone = _comment = null);` to:

```dart
        setState(() {
          _phone = _comment = null;
          _pendingEventId = null;
        });
```

At the start of the `on MealAlreadyTakenFailure catch (e)` branch, add `_pendingEventId = null;`.

4. Add a method after `_confirm`:

```dart
  Future<void> _undo(MealEvent meal) async {
    final l = AppLocalizations.of(context);
    try {
      final p = await ref
          .read(personDetailsProvider(widget.personId).notifier)
          .undoMeal(meal);
      if (mounted) showAppSnackBar(context, l.undone(isolate(p.fullName)));
    } on UndoRefusedFailure catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.tooLate ? l.undoTooLate : l.undoFailed,
          isError: true,
        );
      }
    } on NetworkFailure {
      if (mounted) showAppSnackBar(context, l.undoNeedsConnection, isError: true);
    } on TimeoutFailure {
      if (mounted) showAppSnackBar(context, l.undoNeedsConnection, isError: true);
    } on AppFailure {
      if (mounted) showAppSnackBar(context, l.undoFailed, isError: true);
    }
  }
```

5. In `_body`, replace `final taken = person.isMealTakenToday(ref.watch(clockProvider)());` with:

```dart
    final now = ref.watch(clockProvider)();
    final taken = person.isMealTakenToday(now);
    final undoable = undoableMeal(
      person,
      ref.watch(authControllerProvider).value,
      now,
    );
```

Change both `showMealHistory(context, person)` calls to `showMealHistory(context, person, undoable: undoable, onUndo: _undo)`.

- [ ] **Step 6: The History link on "Already served" in the scanner**

In `scan_result_panel.dart`, add these imports:

```dart
import '../../../core/providers.dart';
import '../../people/domain/undo_rules.dart';
```

In the `ScanAlreadyTaken` case's `_Links([...])`, replace `(l.history, () => showMealHistory(context, person)),` with:

```dart
              (
                l.history,
                () => showMealHistory(
                  context,
                  person,
                  undoable: undoableMeal(
                    person,
                    ref.read(authControllerProvider).value,
                    ref.read(clockProvider)(),
                  ),
                  onUndo: (meal) => controller.undoFromHistory(person, meal),
                ),
              ),
```

- [ ] **Step 7: Strings**

`app_en.arb`:

```json
  "undoTonightsMeal": "Undo tonight’s meal",
  "servedBy": "by {name}",
  "@servedBy": {"placeholders": {"name": {"type": "String"}}},
```

`app_fr.arb`:

```json
  "undoTonightsMeal": "Annuler le repas de ce soir",
  "servedBy": "par {name}",
```

`app_ar.arb`:

```json
  "undoTonightsMeal": "التراجع عن وجبة الليلة",
  "servedBy": "قدّمها {name}",
```

- [ ] **Step 8: Run the tests**

Run Flutter with `test/presentation/person_details_2a_test.dart test/presentation/person_details_test.dart`. Expected: PASS. Then run `flutter test` (all) and `flutter analyze`. Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add apps/mobile/lib apps/mobile/test
git commit -m "feat(mobile): Undo tonight's meal from History, served-by in history, retry-safe confirm on Details

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---
### Task 10: Encrypted copy of the people list on the phone

**Files:**
- Modify: `apps/mobile/pubspec.yaml`, `apps/mobile/pubspec.lock` (add `cryptography`)
- Create: `apps/mobile/lib/features/people/data/people_cache.dart`
- Test: `apps/mobile/test/data/people_cache_test.dart`

**Interfaces:**
- Consumes: Task 5's `FastingPerson.toJson` / `fromJson` (with `_receivedAt`); `SettingsStorage` and `settingsStorageProvider` (existing).
- Produces:
  - `class CachedPeople(List<FastingPerson> people, DateTime syncedAt)`.
  - `abstract interface class PeopleCache { Future<CachedPeople?> read({required int regionId}); Future<void> write({required int regionId, required List<FastingPerson> people, required DateTime syncedAt}); Future<void> clear(); }`.
  - `EncryptedFilePeopleCache({required Future<Directory> Function() directory, required SettingsStorage keys})`, with `fileName` and `keyName`.
  - `MemoryPeopleCache([CachedPeople? saved, int? regionId])`, exposing `saved`, `regionId`, `writes` and `clears`.
  - `peopleCacheProvider`.

> **Gate:** this task adds the only new dependency of the plan (`cryptography`, AES-GCM, pure Dart). The spec marks it as needing approval. If the user hasn't approved it, stop here and ask.

- [ ] **Step 1: Add the dependency**

```bash
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W):/repo" -v iftar_pub_cache:/root/.pub-cache -w /repo/apps/mobile ghcr.io/cirruslabs/flutter:stable sh -c "flutter pub add cryptography"
```

Expected: `pubspec.yaml` gains `cryptography: ^<latest>` and `pubspec.lock` is updated.

- [ ] **Step 2: Write the failing tests**

Create `apps/mobile/test/data/people_cache_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/settings/settings_storage.dart';
import 'package:iftar_mobile/features/people/data/people_cache.dart';

import '../support/fakes.dart';

void main() {
  late Directory dir;
  late MemorySettingsStorage keys;
  late EncryptedFilePeopleCache cache;
  final syncedAt = DateTime(2025, 3, 5, 18, 5);
  final najwa = person(101, takenToday: true).copyWith(receivedAt: syncedAt);
  File file() => File('${dir.path}/${EncryptedFilePeopleCache.fileName}');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('people_cache');
    keys = MemorySettingsStorage();
    cache = EncryptedFilePeopleCache(directory: () async => dir, keys: keys);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('round-trips the list, its time, and each served flag', () async {
    await cache.write(regionId: 1, people: [najwa, person(102)], syncedAt: syncedAt);
    final saved = await cache.read(regionId: 1);
    expect(saved!.syncedAt, syncedAt);
    expect(saved.people.map((p) => p.id), [101, 102]);
    final p = saved.people.first;
    expect(p.fullName, 'Najwa Chalbi');
    expect(p.isMealTakenToday(DateTime(2025, 3, 5, 22)), isTrue);
    // A list saved yesterday never says "served" today.
    expect(p.isMealTakenToday(DateTime(2025, 3, 6, 18)), isFalse);
  });

  test('the file is not readable without the key', () async {
    await cache.write(regionId: 1, people: [najwa], syncedAt: syncedAt);
    final text = String.fromCharCodes(file().readAsBytesSync());
    expect(text.contains('Najwa'), isFalse);
    expect(text.contains('Chalbi'), isFalse);
  });

  test("another region's list is not returned, and is deleted", () async {
    await cache.write(regionId: 1, people: [najwa], syncedAt: syncedAt);
    expect(await cache.read(regionId: 2), isNull);
    expect(file().existsSync(), isFalse);
  });

  test('a lost key (e.g. a restore on a new phone) reads as nothing and cleans up', () async {
    await cache.write(regionId: 1, people: [najwa], syncedAt: syncedAt);
    keys.values.clear();
    expect(await cache.read(regionId: 1), isNull);
    expect(file().existsSync(), isFalse);
  });

  test('a corrupt file reads as nothing', () async {
    file().writeAsBytesSync([1, 2, 3]);
    expect(await cache.read(regionId: 1), isNull);
  });

  test('clear deletes the file and the key', () async {
    await cache.write(regionId: 1, people: [najwa], syncedAt: syncedAt);
    await cache.clear();
    expect(file().existsSync(), isFalse);
    expect(keys.values[EncryptedFilePeopleCache.keyName], isNull);
  });

  test('storage errors never throw', () async {
    final broken = EncryptedFilePeopleCache(
      directory: () async => throw const FileSystemException('no storage'),
      keys: keys,
    );
    await broken.write(regionId: 1, people: [najwa], syncedAt: syncedAt);
    expect(await broken.read(regionId: 1), isNull);
    await broken.clear();
  });
}
```

- [ ] **Step 3: Run them to see them fail**

Run Flutter with `test/data/people_cache_test.dart`. Expected: compile error, because `people_cache.dart` doesn't exist yet.

- [ ] **Step 4: Write the cache**

Create `apps/mobile/lib/features/people/data/people_cache.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/settings/settings_storage.dart';
import '../domain/fasting_person.dart';

class CachedPeople {
  const CachedPeople(this.people, this.syncedAt);

  final List<FastingPerson> people;

  /// When this list was loaded from the server.
  final DateTime syncedAt;
}

/// The region's people list kept on the phone, so volunteers can identify
/// people with no connection (spec 2A §5.4). Best effort: a storage error
/// reads as "nothing saved" and never breaks the app.
abstract interface class PeopleCache {
  /// The saved list for [regionId]; null when none, another region's, or
  /// unreadable.
  Future<CachedPeople?> read({required int regionId});

  Future<void> write({
    required int regionId,
    required List<FastingPerson> people,
    required DateTime syncedAt,
  });

  /// On logout: the list holds names, CIN and phone numbers.
  Future<void> clear();
}

/// AES-GCM encrypted file; the 256-bit key lives in the platform keystore.
class EncryptedFilePeopleCache implements PeopleCache {
  EncryptedFilePeopleCache({
    required Future<Directory> Function() directory,
    required SettingsStorage keys,
  }) : _directory = directory,
       _keys = keys;

  static const fileName = 'people_cache.bin';
  static const keyName = 'people_cache_key';
  static const _version = 1;

  final Future<Directory> Function() _directory;
  final SettingsStorage _keys;
  final AesGcm _algorithm = AesGcm.with256bits();

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  Future<SecretKey> _key({required bool create}) async {
    final stored = await _keys.read(keyName);
    if (stored != null) return SecretKey(base64Decode(stored));
    if (!create) throw StateError('No people cache key');
    final key = await _algorithm.newSecretKey();
    await _keys.write(keyName, base64Encode(await key.extractBytes()));
    return key;
  }

  @override
  Future<CachedPeople?> read({required int regionId}) async {
    try {
      final file = await _file();
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
      final json = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      if (json['v'] != _version || json['regionId'] != regionId) {
        await _delete();
        return null;
      }
      return CachedPeople(
        [
          for (final p in json['people'] as List)
            FastingPerson.fromJson(p as Map<String, dynamic>),
        ],
        DateTime.parse(json['syncedAt'] as String).toLocal(),
      );
    } on Object {
      // Undecryptable (key lost in a restore), corrupt, or no storage.
      await _delete();
      return null;
    }
  }

  @override
  Future<void> write({
    required int regionId,
    required List<FastingPerson> people,
    required DateTime syncedAt,
  }) async {
    try {
      final clear = utf8.encode(
        jsonEncode({
          'v': _version,
          'regionId': regionId,
          'syncedAt': syncedAt.toUtc().toIso8601String(),
          'people': [for (final p in people) p.toJson()],
        }),
      );
      final box = await _algorithm.encrypt(
        clear,
        secretKey: await _key(create: true),
      );
      final file = await _file();
      // Write then rename, so a crash never leaves half a file.
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsBytes(box.concatenation(), flush: true);
      await tmp.rename(file.path);
    } on Object {
      // Best effort: the list on screen is unaffected.
    }
  }

  @override
  Future<void> clear() async {
    await _delete();
    try {
      await _keys.write(keyName, null);
    } on Object {
      // The file is gone; a stray key decrypts nothing.
    }
  }

  Future<void> _delete() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } on Object {
      // Nothing to delete, or no storage.
    }
  }
}

/// In memory, for tests and previews.
class MemoryPeopleCache implements PeopleCache {
  MemoryPeopleCache([this.saved, this.regionId]);

  CachedPeople? saved;
  int? regionId;
  int writes = 0;
  int clears = 0;

  @override
  Future<CachedPeople?> read({required int regionId}) async =>
      regionId == this.regionId ? saved : null;

  @override
  Future<void> write({
    required int regionId,
    required List<FastingPerson> people,
    required DateTime syncedAt,
  }) async {
    this.regionId = regionId;
    saved = CachedPeople(List.of(people), syncedAt);
    writes++;
  }

  @override
  Future<void> clear() async {
    saved = null;
    regionId = null;
    clears++;
  }
}

final peopleCacheProvider = Provider<PeopleCache>(
  (ref) => EncryptedFilePeopleCache(
    directory: getApplicationDocumentsDirectory,
    keys: ref.watch(settingsStorageProvider),
  ),
);
```

- [ ] **Step 5: Run the tests**

Run Flutter with `test/data/people_cache_test.dart`. Expected: PASS (7 tests). Then run `flutter analyze`. Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add apps/mobile/pubspec.yaml apps/mobile/pubspec.lock apps/mobile/lib/features/people/data/people_cache.dart apps/mobile/test/data/people_cache_test.dart
git commit -m "feat(mobile): AES-GCM encrypted copy of the region's people list

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Use the saved list; wipe it on logout; detect offline; say so on screen

**Files:**
- Modify: `apps/mobile/lib/features/people/presentation/people_controller.dart` (`PeopleListController`)
- Modify: `apps/mobile/lib/features/auth/presentation/auth_controller.dart`
- Create: `apps/mobile/lib/core/network/connectivity.dart`
- Modify: `apps/mobile/lib/core/providers.dart` (`dioProvider`)
- Modify: `apps/mobile/lib/features/people/presentation/people_list_page.dart`
- Modify: `apps/mobile/lib/features/scan/presentation/scan_page.dart` (`_TopBar`)
- Modify: `apps/mobile/lib/features/scan/presentation/find_person_page.dart`
- Modify: the 3 ARB files (+ regenerated)
- Modify: `apps/mobile/test/support/fakes.dart`, `apps/mobile/test/presentation/logout_reset_test.dart`
- Test: `apps/mobile/test/presentation/people_cache_flow_test.dart`, `apps/mobile/test/core/connectivity_test.dart`, `apps/mobile/test/presentation/people_list_offline_test.dart`

**Interfaces:**
- Consumes: Task 10's `PeopleCache`, `MemoryPeopleCache`, `CachedPeople` and `peopleCacheProvider`.
- Produces:
  - `PeopleListController.loadedAt`, which for a saved copy is the time it was saved, and `PeopleListController.fromCache`.
  - `ConnectivityController` (`connectivityProvider`, `true` = online) with `reportOnline()` and `reportOffline()`; `healthProbeProvider`; `bool? reachedServer(DioException e)`; `ConnectivityInterceptor`.
  - The localization keys `offlineUsingList(time)`, `lastUpdatedAt(time)` and `offlineIndicator`.
  - In the test fakes, `testOverrides(repo, {cache})` and `FakePeopleRepository.nextListFailure` / `listGate`.

- [ ] **Step 1: Update the fakes**

In `apps/mobile/test/support/fakes.dart`:

1. Add the import `import 'package:iftar_mobile/features/people/data/people_cache.dart';`.
2. In `FakePeopleRepository`, add:

```dart
  AppFailure? nextListFailure;

  /// When set, `list` waits for it (then clears it).
  Completer<void>? listGate;
```

Then make `list` honour them:

```dart
  @override
  Future<List<FastingPerson>> list(int regionId) async {
    listCalls++;
    final gate = listGate;
    if (gate != null) {
      listGate = null;
      await gate.future;
    }
    final failure = nextListFailure;
    if (failure != null) {
      nextListFailure = null;
      throw failure;
    }
    return people.values.toList();
  }
```

3. Change `testOverrides` to take an optional cache and always override it:

```dart
List<Override> testOverrides(
  FakePeopleRepository repo, {
  User? user = testUser,
  DateTime Function()? clock,
  PeopleCache? cache,
}) => [
  authControllerProvider.overrideWith(() => FakeAuthController(user)),
  peopleRepositoryProvider.overrideWithValue(repo),
  clockProvider.overrideWithValue(clock ?? () => testNow),
  deviceIdProvider.overrideWith((ref) async => 'inst-test'),
  peopleCacheProvider.overrideWithValue(cache ?? MemoryPeopleCache()),
];
```

- [ ] **Step 2: Write the failing tests**

Create `apps/mobile/test/presentation/people_cache_flow_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/people/data/people_cache.dart';
import 'package:iftar_mobile/features/people/presentation/people_controller.dart';

import '../support/fakes.dart';

void main() {
  final savedAt = DateTime(2025, 3, 5, 18, 5);
  late FakePeopleRepository repo;
  late MemoryPeopleCache cache;
  late ProviderContainer container;

  PeopleListController list() => container.read(peopleListProvider.notifier);

  Future<void> open() async {
    container = ProviderContainer.test(
      overrides: testOverrides(repo, cache: cache),
    );
    container.listen(peopleListProvider, (_, _) {});
    await container.read(authControllerProvider.future);
  }

  setUp(() {
    repo = FakePeopleRepository([person(101), person(102)]);
    cache = MemoryPeopleCache(
      CachedPeople([person(101, first: 'Saved')], savedAt),
      testRegion.id,
    );
  });

  test("shows the saved list at once, then the server's", () async {
    final gate = Completer<void>();
    repo.listGate = gate;
    await open();
    final first = await container.read(peopleListProvider.future);
    expect(first.single.firstName, 'Saved');
    expect(list().fromCache, isTrue);
    expect(list().loadedAt, savedAt);

    gate.complete();
    await pumpEventQueue();
    final now = container.read(peopleListProvider).value!;
    expect(now.map((p) => p.id), [101, 102]);
    expect(list().fromCache, isFalse);
    expect(cache.saved!.people, hasLength(2));
  });

  test('offline: keeps the saved list, with its time', () async {
    repo.nextListFailure = const NetworkFailure();
    await open();
    await container.read(peopleListProvider.future);
    await pumpEventQueue();
    expect(container.read(peopleListProvider).value!.single.firstName, 'Saved');
    expect(list().fromCache, isTrue);
    expect(list().loadedAt, savedAt);
  });

  test('nothing saved: loads from the server and saves it', () async {
    cache = MemoryPeopleCache();
    await open();
    final people = await container.read(peopleListProvider.future);
    expect(people, hasLength(2));
    expect(list().fromCache, isFalse);
    await pumpEventQueue();
    expect(cache.saved!.people, hasLength(2));
    expect(cache.regionId, testRegion.id);
  });

  test('a confirmed person is saved too', () async {
    cache = MemoryPeopleCache();
    await open();
    await container.read(peopleListProvider.future);
    list().upsert(person(101, takenToday: true));
    await pumpEventQueue();
    expect(
      cache.saved!.people.firstWhere((p) => p.id == 101).isMealTakenToday(testNow),
      isTrue,
    );
  });
}
```

Create `apps/mobile/test/core/connectivity_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/connectivity.dart';

void main() {
  final options = RequestOptions(path: '/x');
  DioException error(DioExceptionType type) =>
      DioException(requestOptions: options, type: type);

  test('an HTTP answer means the server was reached; no answer means it was not', () {
    expect(reachedServer(error(DioExceptionType.badResponse)), isTrue);
    expect(reachedServer(error(DioExceptionType.connectionError)), isFalse);
    expect(reachedServer(error(DioExceptionType.connectionTimeout)), isFalse);
    expect(reachedServer(error(DioExceptionType.receiveTimeout)), isFalse);
    expect(reachedServer(error(DioExceptionType.unknown)), isFalse);
    expect(reachedServer(error(DioExceptionType.cancel)), isNull);
  });

  test('offline probes /health until it answers, then stops', () async {
    var calls = 0;
    var healthy = false;
    final c = ProviderContainer.test(
      overrides: [
        connectivityProvider.overrideWith(
          () => ConnectivityController(
            probeEvery: const Duration(milliseconds: 10),
          ),
        ),
        healthProbeProvider.overrideWithValue(() async {
          calls++;
          if (!healthy) throw Exception('down');
        }),
      ],
    );
    c.listen(connectivityProvider, (_, _) {});
    c.read(connectivityProvider.notifier).reportOffline();
    expect(c.read(connectivityProvider), isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(calls, greaterThan(1));
    expect(c.read(connectivityProvider), isFalse);

    healthy = true;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.read(connectivityProvider), isTrue);
    final settled = calls;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(calls, settled);
  });
}
```

Create `apps/mobile/test/presentation/people_list_offline_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/network/connectivity.dart';
import 'package:iftar_mobile/features/people/data/people_cache.dart';
import 'package:iftar_mobile/features/people/presentation/people_list_page.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

class _Offline extends ConnectivityController {
  @override
  bool build() => false;
}

void main() {
  testWidgets('offline, the list says it is the saved one, and from when', (tester) async {
    final repo = FakePeopleRepository([person(101)])
      ..nextListFailure = const NetworkFailure();
    final cache = MemoryPeopleCache(
      CachedPeople([person(101)], DateTime(2025, 3, 5, 18, 5)),
      testRegion.id,
    );
    await tester.pumpWidget(
      localizedApp(
        const PeopleListPage(),
        overrides: [
          ...testOverrides(repo, cache: cache),
          connectivityProvider.overrideWith(_Offline.new),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('18:05'), findsOneWidget);
    expect(find.textContaining('Najwa Chalbi'), findsOneWidget);
  });
}
```

In `apps/mobile/test/presentation/logout_reset_test.dart`, add the imports `package:iftar_mobile/features/people/data/people_cache.dart` and `package:iftar_mobile/core/storage/device_id.dart` (if needed). Add a `late MemoryPeopleCache cache;`, create it in `setUp` (`cache = MemoryPeopleCache();`) and add `peopleCacheProvider.overrideWithValue(cache)` to that container's overrides. Then add this test:

```dart
  test('signing out wipes the list saved on the phone', () async {
    await container.read(authControllerProvider.notifier).logout();
    expect(cache.clears, 1);
  });
```

- [ ] **Step 3: Run them to see them fail**

Run Flutter with `test/presentation/people_cache_flow_test.dart test/core/connectivity_test.dart test/presentation/people_list_offline_test.dart test/presentation/logout_reset_test.dart`. Expected: compile errors (`fromCache`, `connectivity.dart` and the cache isn't used yet).

- [ ] **Step 4: `PeopleListController` reads and writes the saved list**

In `people_controller.dart`, add the imports `dart:async` and `../data/people_cache.dart`. Then replace the class from its start down to (but not including) `reloadIfDayChanged` with:

```dart
/// The region's list of fasting people (Ionic tab "list").
class PeopleListController extends AsyncNotifier<List<FastingPerson>> {
  /// When the list on screen was loaded from the server (for the copy saved
  /// on the phone: when that copy was). The "served tonight" flags in it
  /// describe that day only.
  DateTime? loadedAt;

  /// True while the list on screen is the copy saved on this phone and no
  /// server answer has replaced it yet (spec 2A §5.4).
  bool fromCache = false;

  @override
  Future<List<FastingPerson>> build() async {
    // Reload when the signed-in user's region changes.
    ref.watch(authControllerProvider.select((a) => a.value?.region?.id));
    loadedAt = null;
    fromCache = false;
    final region = requireRegion(ref);
    final saved = await ref
        .read(peopleCacheProvider)
        .read(regionId: region.id);
    if (saved != null) {
      loadedAt = saved.syncedAt;
      fromCache = true;
      // Shown at once; the server's list replaces it when it arrives.
      unawaited(_refreshQuietly());
      return saved.people;
    }
    return _load();
  }

  Future<List<FastingPerson>> _load() async {
    final region = requireRegion(ref);
    final people = await ref.read(peopleRepositoryProvider).list(region.id);
    loadedAt = ref.read(clockProvider)();
    fromCache = false;
    _save(people);
    return people;
  }

  Future<void> _refreshQuietly() async {
    try {
      final people = await _load();
      if (ref.mounted) state = AsyncData(people);
    } on Object {
      // Offline: the saved list stays on screen, marked with its time.
    }
  }

  /// Keeps the copy on the phone in step with the list on screen.
  void _save(List<FastingPerson> people) {
    final region = ref.read(authControllerProvider).value?.region;
    final at = loadedAt;
    if (region == null || at == null) return;
    unawaited(
      ref
          .read(peopleCacheProvider)
          .write(regionId: region.id, people: people, syncedAt: at),
    );
  }
```

Then add `_save(next);` as the last line of `upsert`, and `_save(state.value!);` as the last line of `remove`, after the `state = AsyncData(...)` assignments.

- [ ] **Step 5: Logout wipes it**

In `auth_controller.dart`, add `import '../../people/data/people_cache.dart';`. In `_signOut`, after `await _repo.logout();`, add:

```dart
    // The saved list holds names, CIN and phone numbers (spec 2A §6).
    await ref.read(peopleCacheProvider).clear();
```

- [ ] **Step 6: Connectivity from request outcomes**

Create `apps/mobile/lib/core/network/connectivity.dart`:

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'api_client.dart';

/// What a failed request says about the connection: true = the server
/// answered (with an error), false = it could not be reached, null = no
/// information (cancelled).
bool? reachedServer(DioException e) => switch (e.type) {
  DioExceptionType.badResponse => true,
  DioExceptionType.cancel => null,
  _ => false,
};

/// Whether the server is reachable, judged from real request outcomes
/// (spec 2A §5.5), with no connectivity plugin. While offline, `GET /health`
/// is tried every [probeEvery] so the app notices when the network is back.
class ConnectivityController extends Notifier<bool> {
  ConnectivityController({this.probeEvery = const Duration(seconds: 15)});

  final Duration probeEvery;
  Timer? _probe;

  @override
  bool build() {
    ref.onDispose(() => _probe?.cancel());
    return true;
  }

  void reportOnline() {
    _probe?.cancel();
    _probe = null;
    if (!state) state = true;
  }

  void reportOffline() {
    if (state) state = false;
    _probe ??= Timer.periodic(probeEvery, (_) => _probeOnce());
  }

  Future<void> _probeOnce() async {
    try {
      await ref.read(healthProbeProvider)();
      if (ref.mounted) reportOnline();
    } on Object {
      // Still offline.
    }
  }
}

final connectivityProvider = NotifierProvider<ConnectivityController, bool>(
  ConnectivityController.new,
);

/// One `GET /health` on its own client, outside the app's interceptors.
final healthProbeProvider = Provider<Future<void> Function()>((ref) {
  final options = ApiClient.baseOptions(ref.watch(appConfigProvider).apiBaseUrl)
    ..connectTimeout = const Duration(seconds: 5)
    ..receiveTimeout = const Duration(seconds: 5);
  final dio = Dio(options);
  ref.onDispose(dio.close);
  return () async {
    await dio.get<dynamic>('/health');
  };
});

/// Feeds every request outcome to [ConnectivityController].
class ConnectivityInterceptor extends Interceptor {
  ConnectivityInterceptor({required this.onOnline, required this.onOffline});

  final void Function() onOnline;
  final void Function() onOffline;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    onOnline();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    switch (reachedServer(err)) {
      case true:
        onOnline();
      case false:
        onOffline();
      case null:
        break;
    }
    handler.next(err);
  }
}
```

In `apps/mobile/lib/core/providers.dart`, add `import 'network/connectivity.dart';`. In `dioProvider`, extend the cascade after the `AuthInterceptor` add:

```dart
    ..interceptors.add(
      ConnectivityInterceptor(
        onOnline: () => ref.read(connectivityProvider.notifier).reportOnline(),
        onOffline: () =>
            ref.read(connectivityProvider.notifier).reportOffline(),
      ),
    );
```

Keep a single `;` at the end of the whole cascade.

- [ ] **Step 7: Say it on screen**

1. In `people_list_page.dart`, add the imports `../../../core/network/connectivity.dart` and `../../../core/utils/formatters.dart` (if it isn't already imported). In `build`, after `final filter = …`, add:

```dart
    final online = ref.watch(connectivityProvider);
    final listState = ref.read(peopleListProvider.notifier);
    final savedAt = listState.loadedAt;
    final syncNote = !people.hasValue || savedAt == null
        ? null
        : !online
        ? l.offlineUsingList(ltr(formatTime(savedAt)))
        : listState.fromCache
        ? l.lastUpdatedAt(ltr(formatTime(savedAt)))
        : null;
```

In the `slivers:` list, right after the `_Header` sliver, add:

```dart
            if (syncNote != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(18, 10, 18, 0),
                  child: Row(
                    children: [
                      Icon(
                        online ? Icons.history_rounded : Icons.cloud_off_rounded,
                        size: 16,
                        color: context.colors.goldInk,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          syncNote,
                          style: TextStyle(fontSize: 12.5, color: context.colors.goldInk),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
```

2. In `scan_page.dart`, add `import '../../../core/network/connectivity.dart';`. Pass `offline: !ref.watch(connectivityProvider),` to `_TopBar(...)`. Add `required this.offline,` and `final bool offline;` to `_TopBar`. In `_TopBar.build`'s `Row`, before `if (showFind) ...[`, add:

```dart
          if (offline) ...[
            Tooltip(
              message: l.offlineIndicator,
              child: const Icon(Icons.cloud_off_rounded, color: AppPalette.gold),
            ),
            const SizedBox(width: 8),
          ],
```

3. In `find_person_page.dart`, add the imports `../../../core/network/connectivity.dart` and `../../people/presentation/people_controller.dart` (if it isn't already imported). In `build`, compute:

```dart
    final offlineAt = ref.watch(connectivityProvider)
        ? null
        : ref.read(peopleListProvider.notifier).loadedAt;
```

In the `SkyBand`'s `Column`, after the search field's `Padding`, add:

```dart
                if (offlineAt != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12, top: 8),
                    child: Text(
                      l.offlineUsingList(ltr(formatTime(offlineAt))),
                      style: const TextStyle(color: AppPalette.gold, fontSize: 12.5),
                    ),
                  ),
```

`formatTime` and `ltr` come from `core/utils/formatters.dart`, which this page already imports for `latinDigits`.

- [ ] **Step 8: Strings**

`app_en.arb`:

```json
  "offlineUsingList": "Offline · using the list saved at {time}",
  "@offlineUsingList": {"placeholders": {"time": {"type": "String"}}},
  "lastUpdatedAt": "Last updated {time}",
  "@lastUpdatedAt": {"placeholders": {"time": {"type": "String"}}},
  "offlineIndicator": "Offline",
```

`app_fr.arb`:

```json
  "offlineUsingList": "Hors ligne · liste enregistrée à {time}",
  "lastUpdatedAt": "Mis à jour à {time}",
  "offlineIndicator": "Hors ligne",
```

`app_ar.arb`:

```json
  "offlineUsingList": "غير متصل · القائمة المحفوظة على الساعة {time}",
  "lastUpdatedAt": "آخر تحديث على الساعة {time}",
  "offlineIndicator": "غير متصل",
```

- [ ] **Step 9: Run the tests**

Run Flutter with `test/presentation/people_cache_flow_test.dart test/core/connectivity_test.dart test/presentation/people_list_offline_test.dart test/presentation/logout_reset_test.dart`. Expected: PASS. Then run `flutter test` (all) and `flutter analyze`. Expected: PASS.

A test that counts `listCalls` right after startup can now see a background refresh only when a saved list exists. `testOverrides` starts with an empty cache, so existing tests behave as before.

- [ ] **Step 10: Commit**

```bash
git add apps/mobile/lib apps/mobile/test
git commit -m "feat(mobile): saved list shown at once and used offline, wiped on logout; offline detected from requests and shown

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Read-only offline identify in the scanner

**Files:**
- Modify: `apps/mobile/lib/features/scan/presentation/scan_controller.dart`
- Modify: `apps/mobile/lib/features/scan/presentation/scan_result_panel.dart`
- Modify: `apps/mobile/lib/features/scan/presentation/scan_page.dart`
- Modify: the 3 ARB files (+ regenerated)
- Test: `apps/mobile/test/presentation/scan_controller_test.dart`, `apps/mobile/test/presentation/scan_result_panel_2a_test.dart`

**Interfaces:**
- Consumes: Task 11's `PeopleListController.loadedAt`; Task 7's statuses.
- Produces:
  - `ScanUnverified(FastingPerson person, {required DateTime syncedAt, bool noCard})`.
  - `ScanNotOnPhone(int personId, {bool noCard})`.
  - `ScanAlreadyTaken(..., {DateTime? asOf})`.
  - `retry()` also covers these states.
  - The localization keys `cantCheckTonight`, `lastSyncNotServed(time)`, `asOfTime(time)`, `notOnPhoneTitle(id)` and `notOnPhoneMessage`.
  - **None of the new states can confirm.** Spec 2B adds "Serve offline" to `ScanUnverified`.

- [ ] **Step 1: Write the failing tests, and update the two old ones that assumed a plain failure**

In `scan_controller_test.dart`, replace the test `'network error on lookup → failed, retry succeeds'` with:

```dart
  test('no answer on lookup, person on the phone → unverified, retry asks again', () async {
    await container.read(peopleListProvider.future); // the list on the phone
    repo.nextGetFailure = const NetworkFailure();
    await controller().onDetected('101');
    final status = state().status;
    expect(status, isA<ScanUnverified>());
    expect(state().acceptsScans, isTrue);

    await controller().retry();
    expect(state().status, isA<ScanReady>());
  });
```

In group `'fix round 1'`, replace `'the CIN check survives a failed lookup and its retry'` with:

```dart
    test('the CIN check survives a lookup with no answer, and its retry', () async {
      await container.read(peopleListProvider.future);
      repo.nextGetFailure = const NetworkFailure();
      await controller().pickWithoutCard(101);
      final unverified = state().status;
      expect(unverified, isA<ScanUnverified>());
      expect((unverified as ScanUnverified).noCard, isTrue);
      await controller().retry();
      final status = state().status;
      expect(status, isA<ScanReady>());
      expect((status as ScanReady).noCard, isTrue);
    });
```

Then add a new group at the end of `main()`:

```dart
  group('spec 2A: offline identify (read-only)', () {
    test('served tonight on the phone → already served, as of the saved list', () async {
      await container.read(peopleListProvider.future);
      repo.nextGetFailure = const TimeoutFailure();
      await controller().onDetected('102');
      final status = state().status as ScanAlreadyTaken;
      expect(status.asOf, isNotNull);
      expect(repo.confirmCalls, 0);
    });

    test('not on the phone → says so', () async {
      await container.read(peopleListProvider.future);
      repo.nextGetFailure = const NetworkFailure();
      await controller().onDetected('999');
      expect(state().status, isA<ScanNotOnPhone>());
      expect((state().status as ScanNotOnPhone).personId, 999);
    });

    test("yesterday's saved list never says served tonight", () async {
      repo.people[102] = person(
        102,
        takenToday: true,
        first: 'Aziza',
        last: 'Ouerghi',
      ).copyWith(receivedAt: testNow);
      await container.read(peopleListProvider.future);
      now = now.add(const Duration(days: 1));
      repo.nextGetFailure = const NetworkFailure();
      await controller().onDetected('102');
      expect(state().status, isA<ScanUnverified>());
    });

    test('a server error is still a plain failure, not "offline"', () async {
      await container.read(peopleListProvider.future);
      repo.nextGetFailure = const ServerFailure(statusCode: 500);
      await controller().onDetected('101');
      expect(state().status, isA<ScanFailed>());
    });

    test('unverified cannot be confirmed', () async {
      await container.read(peopleListProvider.future);
      repo.nextGetFailure = const NetworkFailure();
      await controller().onDetected('101');
      await controller().confirm();
      expect(repo.confirmCalls, 0);
      expect(state().status, isA<ScanUnverified>());
    });
  });
```

Add to `scan_result_panel_2a_test.dart`:

```dart
  testWidgets('unverified: says it cannot check, shows the hand-over, offers Retry', (tester) async {
    final repo = FakePeopleRepository([person(101)]);
    await tester.pumpWidget(
      panel(ScanUnverified(person(101), syncedAt: DateTime(2025, 3, 5, 18, 5)), repo),
    );
    await tester.pump();
    expect(find.text(en.cantCheckTonight), findsOneWidget);
    expect(find.textContaining('18:05'), findsOneWidget);
    expect(find.text(en.retry), findsOneWidget);
    expect(find.text(en.confirmHandOver), findsNothing);
  });

  testWidgets('not on this phone: says so, offers Retry and Scan again', (tester) async {
    final repo = FakePeopleRepository([]);
    await tester.pumpWidget(panel(const ScanNotOnPhone(999), repo));
    await tester.pump();
    expect(find.text(en.notOnPhoneTitle(999)), findsOneWidget);
    expect(find.text(en.retry), findsOneWidget);
    expect(find.text(en.scanAgain), findsOneWidget);
  });
```

- [ ] **Step 2: Run them to see them fail**

Run Flutter with `test/presentation/scan_controller_test.dart test/presentation/scan_result_panel_2a_test.dart`. Expected: compile errors (`ScanUnverified`, `ScanNotOnPhone` and `asOf` don't exist yet).

- [ ] **Step 3: Controller**

In `scan_controller.dart`:

1. Add after `ScanNotFound`:

```dart
/// No answer from the server, but the person is in the list saved on this
/// phone and was not served as of [syncedAt]. Display only: it can't be
/// confirmed (spec 2A §5.6; Spec 2B adds "Serve offline").
final class ScanUnverified extends ScanStatus {
  const ScanUnverified(this.person, {required this.syncedAt, this.noCard = false});
  final FastingPerson person;
  final DateTime syncedAt;
  final bool noCard;
}

/// No answer from the server, and this ID isn't in the list saved on this phone.
final class ScanNotOnPhone extends ScanStatus {
  const ScanNotOnPhone(this.personId, {this.noCard = false});
  final int personId;
  final bool noCard;
}
```

2. Give `ScanAlreadyTaken` an optional `this.asOf` and the field:

```dart
  /// Set when the verdict comes from the list saved on the phone (no answer
  /// from the server): "as of" that time.
  final DateTime? asOf;
```

3. In `acceptsScans`, add `ScanUnverified() || ScanNotOnPhone()` to the `=> true` group.

4. In `_lookup`, replace the final `catch (e) { … }` block with:

```dart
    } catch (e) {
      if (!_stillLookingUp(personId)) return;
      final failure = toAppFailure(e);
      _set(
        failure is NetworkFailure || failure is TimeoutFailure
            ? _offlineVerdict(personId, noCard)
            : ScanFailed(failure, personId: personId, noCard: noCard),
      );
    }
```

5. Add after `_lookup`:

```dart
  /// No answer from the server: what the list saved on this phone says,
  /// clearly marked as such. Never a confirm (spec 2A §5.6).
  ScanStatus _offlineVerdict(int personId, bool noCard) {
    final cached = _cached(personId);
    final syncedAt = ref.read(peopleListProvider.notifier).loadedAt;
    if (cached == null || syncedAt == null) {
      return ScanNotOnPhone(personId, noCard: noCard);
    }
    if (cached.isMealTakenToday(_now())) {
      final meal = cached.todayMealAt(_now());
      return ScanAlreadyTaken(
        cached,
        meal?.servedAt ?? cached.lastTakenMeal,
        servedByName: meal?.servedByName,
        asOf: syncedAt,
      );
    }
    return ScanUnverified(cached, syncedAt: syncedAt, noCard: noCard);
  }
```

6. Replace `retry()` with:

```dart
  Future<void> retry() async {
    switch (state.status) {
      case ScanFailed(duringConfirm: true):
        await confirm();
      case ScanFailed(:final personId, :final noCard):
        await _lookup(personId, noCard: noCard);
      case ScanUnverified(:final person, :final noCard):
        await _lookup(person.id, noCard: noCard);
      case ScanNotOnPhone(:final personId, :final noCard):
        await _lookup(personId, noCard: noCard);
      default:
        return;
    }
  }
```

- [ ] **Step 4: Panel**

In `scan_result_panel.dart`:

1. Add to `_keyFor`:

```dart
    ScanUnverified(:final person) => 'unverified-${person.id}',
    ScanNotOnPhone(:final personId) => 'notonphone-$personId',
```

2. In the `ScanAlreadyTaken` case, destructure `:final asOf` and change the band's `subtitle:` to:

```dart
            subtitle: asOf == null
                ? l.alreadyServedTonight
                : '${l.alreadyServedTonight} ${l.asOfTime(ltr(formatTime(asOf)))}',
```

3. Add these two cases before `case ScanFailed(...)`:

```dart
      case ScanUnverified(:final person, :final syncedAt, :final noCard):
        return _Sheet(
          band: _Band(
            color: c.systemBand,
            seal: problem,
            title: l.cantCheckTonight,
            subtitle: l.lastSyncNotServed(ltr(formatTime(syncedAt))),
            small: true,
          ),
          header: [
            _Name(person),
            _PersonMeta(person),
            if (noCard) _NoCardCheck(person),
          ],
          body: [
            _Label(l.handOver),
            HandOverTiles(person: person),
          ],
          footer: [
            FilledButton.icon(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l.retry),
            ),
            _Links([(l.skip, controller.scanNext)]),
          ],
        );

      case ScanNotOnPhone(:final personId):
        return _Sheet(
          band: _Band(
            color: c.systemBand,
            seal: problem,
            title: l.notOnPhoneTitle(personId),
            subtitle: l.notOnPhoneMessage,
            small: true,
          ),
          body: [
            FilledButton.icon(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l.retry),
            ),
            _Links([(l.scanAgain, controller.scanNext)]),
          ],
        );
```

- [ ] **Step 5: Page switches**

In `scan_page.dart`:
- In `_hapticsFor`, change `case ScanInvalidCode() || ScanNotFound() || ScanFailed():` to `case ScanInvalidCode() || ScanNotFound() || ScanFailed() || ScanUnverified() || ScanNotOnPhone():`.
- In `frameColor`, add `ScanUnverified() || ScanNotOnPhone()` to the `AppPalette.gold` group.

- [ ] **Step 6: Strings**

`app_en.arb`:

```json
  "cantCheckTonight": "Can’t check tonight",
  "lastSyncNotServed": "Last sync {time}: not served yet",
  "@lastSyncNotServed": {"placeholders": {"time": {"type": "String"}}},
  "asOfTime": "(as of {time})",
  "@asOfTime": {"placeholders": {"time": {"type": "String"}}},
  "notOnPhoneTitle": "Card #{id} isn’t on this phone",
  "@notOnPhoneTitle": {"placeholders": {"id": {"type": "int"}}},
  "notOnPhoneMessage": "No connection, and this card isn’t in the list saved on this phone.",
```

`app_fr.arb`:

```json
  "cantCheckTonight": "Impossible de vérifier ce soir",
  "lastSyncNotServed": "Dernière synchro {time} : pas encore servi",
  "asOfTime": "(à {time})",
  "notOnPhoneTitle": "La carte n°{id} n’est pas sur ce téléphone",
  "notOnPhoneMessage": "Pas de connexion, et cette carte n’est pas dans la liste enregistrée sur ce téléphone.",
```

`app_ar.arb`:

```json
  "cantCheckTonight": "تعذّر التحقق الليلة",
  "lastSyncNotServed": "آخر مزامنة {time}: لم يستلم بعد",
  "asOfTime": "(حتى الساعة {time})",
  "notOnPhoneTitle": "البطاقة رقم {id} غير موجودة على هذا الهاتف",
  "notOnPhoneMessage": "لا يوجد اتصال، وهذه البطاقة ليست في القائمة المحفوظة على هذا الهاتف.",
```

- [ ] **Step 7: Run the tests**

Run Flutter with `test/presentation/scan_controller_test.dart test/presentation/scan_result_panel_2a_test.dart`. Expected: PASS. Then run `flutter test` (all) and `flutter analyze`. Expected: PASS.

If a `scan_page_test.dart` or `find_person_test.dart` test expects the old failure sheet after a *network* failure on lookup, it now gets "Not on this phone" or "Can't check tonight". Update its expectation to the new text. A *server* failure still shows the old sheet.

- [ ] **Step 8: Commit**

```bash
git add apps/mobile/lib apps/mobile/test
git commit -m "feat(mobile): read-only offline identify from the saved list (can't check tonight, not on this phone, as of)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Full verification and hand-over

**Files:**
- Modify: `docs/superpowers/specs/2026-10-01-serving-safety-backend-design.md` (status line only)

- [ ] **Step 1: Every suite, from clean**

Run each of these:
- the backend unit tests (pattern `.`)
- the backend e2e tests (pattern `.`)
- the backend `npm run lint`
- `npm run build` in the backend container
- Flutter `flutter test` (all)
- Flutter `flutter analyze`

Expected: all PASS, with 0 analyzer issues and 0 lint errors. If anything fails, fix it before going on, using superpowers:systematic-debugging.

- [ ] **Step 2: Contract check against a real backend (optional, when the dev stack is up)**

If `iftar-test-api` is running (see `docs/DEPLOYMENT.md`), run `test/integration/api_contract_test.dart` with `--dart-define=IT_API_BASE_URL=…`. That proves the Flutter data layer parses the real `todayMeal`, `meal` and 409 bodies.

- [ ] **Step 3: Mark the spec**

In the spec's header, change `- **Status:** Draft for review` to `- **Status:** Implemented (branch feat/serving-safety-2a, plan docs/superpowers/plans/2026-10-07-serving-safety-2a.md)`.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/specs/2026-10-01-serving-safety-backend-design.md
git commit -m "docs: mark Spec 2A implemented

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Hand the field check to the user (do not run it)**

Report these manual checks from spec §8. They need real phones:
1. Throttle a phone to 2G or EDGE and confirm 20 people in a row. Watch for "Sending… slow connection", the automatic retry, and no double meals in `meal_events`.
2. Turn on airplane mode, restart the app, and identify 10 people. Check "Can't check tonight", "Already served (as of …)", "Not on this phone", and the offline note on People and Find.
3. Confirm, tap Undo, and check that the person can be served again. Then confirm, wait 11 minutes, and check that History no longer offers Undo.
4. Log out with no network and log in as another volunteer: no saved list may appear.
5. Remember the deploy order: the backend first. The migration runs on container start (`apps/backend/Dockerfile`). Then the app.

Then use superpowers:finishing-a-development-branch.
