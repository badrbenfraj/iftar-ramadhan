import { MigrationInterface, QueryRunner } from "typeorm";

export class Addregionenum1710543356903 implements MigrationInterface {
    name = 'Addregionenum1710543356903'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "fastings" ADD CONSTRAINT "PK_20dd97bf45615e8f88763b9cd6b" PRIMARY KEY ("id", "region")`);
        await queryRunner.query(`ALTER TYPE "public"."region_enum" RENAME TO "region_enum_old"`);
        await queryRunner.query(`CREATE TYPE "public"."fastings_region_enum" AS ENUM('sokra', 'sousse')`);
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "region" DROP DEFAULT`);
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "region" TYPE "public"."fastings_region_enum" USING "region"::"text"::"public"."fastings_region_enum"`);
        await queryRunner.query(`DROP TYPE "public"."region_enum_old"`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."region_enum_old" AS ENUM('sokra', 'sousse')`);
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "region" TYPE "public"."region_enum_old" USING "region"::"text"::"public"."region_enum_old"`);
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "region" SET DEFAULT 'sokra'`);
        await queryRunner.query(`DROP TYPE "public"."fastings_region_enum"`);
        await queryRunner.query(`ALTER TYPE "public"."region_enum_old" RENAME TO "region_enum"`);
        await queryRunner.query(`ALTER TABLE "fastings" DROP CONSTRAINT "PK_20dd97bf45615e8f88763b9cd6b"`);
    }

}
