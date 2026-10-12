import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Every region prints the same card numbers, so a person is identified by
 * (region, card number). Meal events point to that pair, and "one meal per
 * night" is per person of a region.
 */
export class PersonKeyPerRegion1791700000000 implements MigrationInterface {
  name = 'PersonKeyPerRegion1791700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "meal_events" DROP CONSTRAINT "FK_meal_events_fasting"`,
    );
    await queryRunner.query(`DROP INDEX "UQ_meal_events_active_day"`);
    await queryRunner.query(`DROP INDEX "IDX_meal_events_fasting_served"`);
    // A person used to be movable to another region without their meals
    // following; re-point them while "id" alone is still unique.
    await queryRunner.query(
      `UPDATE "meal_events" e SET "regionId" = f."regionId"
         FROM "fastings" f
        WHERE f."id" = e."fastingId" AND e."regionId" IS DISTINCT FROM f."regionId"`,
    );
    const [{ count }]: Array<{ count: string }> = await queryRunner.query(
      `SELECT count(*) AS "count" FROM "fastings" WHERE "regionId" IS NULL`,
    );
    if (Number(count) > 0) {
      throw new Error(
        `${count} fasting people have no region: give them one before migrating`,
      );
    }
    await queryRunner.query(
      `ALTER TABLE "fastings" DROP CONSTRAINT "PK_33563b1cc12321877ca97148150"`,
    );
    await queryRunner.query(
      `ALTER TABLE "fastings" ADD CONSTRAINT "PK_fastings_region_card" PRIMARY KEY ("regionId", "id")`,
    );
    await queryRunner.query(
      `ALTER TABLE "meal_events" ADD CONSTRAINT "FK_meal_events_fasting" FOREIGN KEY ("regionId", "fastingId") REFERENCES "fastings"("regionId", "id") ON DELETE CASCADE`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_meal_events_active_day" ON "meal_events" ("regionId", "fastingId", "serviceDay") WHERE "revokedAt" IS NULL AND "conflict" = false`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_meal_events_fasting_served" ON "meal_events" ("regionId", "fastingId", "servedAt")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "IDX_meal_events_fasting_served"`);
    await queryRunner.query(`DROP INDEX "UQ_meal_events_active_day"`);
    await queryRunner.query(
      `ALTER TABLE "meal_events" DROP CONSTRAINT "FK_meal_events_fasting"`,
    );
    await queryRunner.query(
      `ALTER TABLE "fastings" DROP CONSTRAINT "PK_fastings_region_card"`,
    );
    // Fails if a card number is now used in two regions: intended.
    await queryRunner.query(
      `ALTER TABLE "fastings" ADD CONSTRAINT "PK_33563b1cc12321877ca97148150" PRIMARY KEY ("id")`,
    );
    await queryRunner.query(
      `ALTER TABLE "meal_events" ADD CONSTRAINT "FK_meal_events_fasting" FOREIGN KEY ("fastingId") REFERENCES "fastings"("id") ON DELETE CASCADE`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_meal_events_active_day" ON "meal_events" ("fastingId", "serviceDay") WHERE "revokedAt" IS NULL AND "conflict" = false`,
    );
    await queryRunner.query(
      `CREATE INDEX "IDX_meal_events_fasting_served" ON "meal_events" ("fastingId", "servedAt")`,
    );
  }
}
