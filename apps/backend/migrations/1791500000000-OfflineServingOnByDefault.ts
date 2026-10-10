import { MigrationInterface, QueryRunner } from 'typeorm';

/** Offline serving is on by default; admins can still turn it off per region. */
export class OfflineServingOnByDefault1791500000000 implements MigrationInterface {
  name = 'OfflineServingOnByDefault1791500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "regions" ALTER COLUMN "allowOfflineServing" SET DEFAULT true`,
    );
    await queryRunner.query(
      `UPDATE "regions" SET "allowOfflineServing" = true`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "regions" ALTER COLUMN "allowOfflineServing" SET DEFAULT false`,
    );
  }
}
