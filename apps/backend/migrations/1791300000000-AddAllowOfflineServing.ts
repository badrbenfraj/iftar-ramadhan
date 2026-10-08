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
