import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Admins manage regions from the app:
 * - rename: users and fastings point to regions by (id, name), so the name
 *   must cascade on update;
 * - close: `closedAt` marks when serving stopped (offline meals recorded
 *   before it still sync), `previousRegionId` lets volunteers moved out of a
 *   closed region sync the meals they served there.
 */
export class RegionCloseAndRename1791600000000 implements MigrationInterface {
  name = 'RegionCloseAndRename1791600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "regions" ADD "closedAt" TIMESTAMP WITH TIME ZONE`,
    );
    await queryRunner.query(
      `UPDATE "regions" SET "closedAt" = "updatedAt" WHERE "active" = false`,
    );
    await queryRunner.query(`ALTER TABLE "users" ADD "previousRegionId" integer`);

    await queryRunner.query(
      `ALTER TABLE "fastings" DROP CONSTRAINT "FK_18d2034cb39130e79816e075880"`,
    );
    await queryRunner.query(
      `ALTER TABLE "fastings" ADD CONSTRAINT "FK_18d2034cb39130e79816e075880" FOREIGN KEY ("regionId", "regionName") REFERENCES "regions"("id","name") ON DELETE NO ACTION ON UPDATE CASCADE`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP CONSTRAINT "FK_a1aa37f135c5949cfde6825546a"`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD CONSTRAINT "FK_a1aa37f135c5949cfde6825546a" FOREIGN KEY ("regionId", "regionName") REFERENCES "regions"("id","name") ON DELETE NO ACTION ON UPDATE CASCADE`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" DROP CONSTRAINT "FK_a1aa37f135c5949cfde6825546a"`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD CONSTRAINT "FK_a1aa37f135c5949cfde6825546a" FOREIGN KEY ("regionId", "regionName") REFERENCES "regions"("id","name") ON DELETE NO ACTION ON UPDATE NO ACTION`,
    );
    await queryRunner.query(
      `ALTER TABLE "fastings" DROP CONSTRAINT "FK_18d2034cb39130e79816e075880"`,
    );
    await queryRunner.query(
      `ALTER TABLE "fastings" ADD CONSTRAINT "FK_18d2034cb39130e79816e075880" FOREIGN KEY ("regionId", "regionName") REFERENCES "regions"("id","name") ON DELETE NO ACTION ON UPDATE NO ACTION`,
    );
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "previousRegionId"`);
    await queryRunner.query(`ALTER TABLE "regions" DROP COLUMN "closedAt"`);
  }
}
