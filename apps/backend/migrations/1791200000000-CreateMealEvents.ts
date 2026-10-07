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
