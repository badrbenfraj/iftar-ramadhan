import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Sign-up only with a region's code (no public list of regions); each region
 * decides whether new volunteers wait for approval.
 */
export class CodeOnlySignUp1791800000000 implements MigrationInterface {
  name = 'CodeOnlySignUp1791800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "regions" ADD "approveNewVolunteers" boolean NOT NULL DEFAULT true`,
    );
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "joinedWithCode"`);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD "joinedWithCode" boolean NOT NULL DEFAULT false`,
    );
    await queryRunner.query(
      `ALTER TABLE "regions" DROP COLUMN "approveNewVolunteers"`,
    );
  }
}
