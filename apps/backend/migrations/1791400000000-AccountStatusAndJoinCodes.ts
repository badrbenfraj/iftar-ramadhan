import { MigrationInterface, QueryRunner } from 'typeorm';

/** Security spec §3.1: account status replaces isAccountDisabled; region join codes. */
export class AccountStatusAndJoinCodes1791400000000
  implements MigrationInterface
{
  name = 'AccountStatusAndJoinCodes1791400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "users" ADD "status" character varying(16) NOT NULL DEFAULT 'active'`,
    );
    await queryRunner.query(
      `UPDATE "users" SET "status" = CASE WHEN "isAccountDisabled" THEN 'disabled' ELSE 'active' END`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD CONSTRAINT "CHK_users_status" CHECK ("status" IN ('pending', 'active', 'disabled'))`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP COLUMN "isAccountDisabled"`,
    );
    await queryRunner.query(`ALTER TABLE "users" ADD "approvedByUserId" integer`);
    await queryRunner.query(
      `ALTER TABLE "users" ADD "approvedAt" TIMESTAMP WITH TIME ZONE`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" ADD "joinedWithCode" boolean NOT NULL DEFAULT false`,
    );
    await queryRunner.query(
      `ALTER TABLE "regions" ADD "joinCode" character varying(32)`,
    );
    await queryRunner.query(
      `CREATE UNIQUE INDEX "UQ_regions_joinCode" ON "regions" ("joinCode") WHERE "joinCode" IS NOT NULL`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "UQ_regions_joinCode"`);
    await queryRunner.query(`ALTER TABLE "regions" DROP COLUMN "joinCode"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "joinedWithCode"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "approvedAt"`);
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "approvedByUserId"`);
    await queryRunner.query(
      `ALTER TABLE "users" ADD "isAccountDisabled" boolean NOT NULL DEFAULT false`,
    );
    await queryRunner.query(
      `UPDATE "users" SET "isAccountDisabled" = ("status" <> 'active')`,
    );
    await queryRunner.query(
      `ALTER TABLE "users" DROP CONSTRAINT "CHK_users_status"`,
    );
    await queryRunner.query(`ALTER TABLE "users" DROP COLUMN "status"`);
  }
}
