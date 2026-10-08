import { DataSource, MigrationInterface } from 'typeorm';

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

const open = async (
  migrations: Array<new () => MigrationInterface>,
): Promise<DataSource> => {
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
