import { MigrationInterface, QueryRunner } from "typeorm";

export class Migrateall1740313869650 implements MigrationInterface {
    name = 'Migrateall1740313869650'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "users" DROP CONSTRAINT "valid_region_enum"`);
        await queryRunner.query(`ALTER TABLE "fastings" ADD "phone" character varying`);
        await queryRunner.query(`ALTER TABLE "fastings" ADD "comment" text`);
        await queryRunner.query(`ALTER TABLE "fastings" ADD CONSTRAINT "PK_20dd97bf45615e8f88763b9cd6b" PRIMARY KEY ("id", "region")`);
        await queryRunner.query(`ALTER TYPE "public"."region_enum" RENAME TO "region_enum_old"`);
        await queryRunner.query(`CREATE TYPE "public"."fastings_region_enum" AS ENUM('sokra', 'sousse')`);
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "region" DROP DEFAULT`);
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "region" TYPE "public"."fastings_region_enum" USING "region"::"text"::"public"."fastings_region_enum"`);
        await queryRunner.query(`DROP TYPE "public"."region_enum_old"`);
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "lastTakenMeal" DROP DEFAULT`);
        await queryRunner.query(`ALTER TABLE "fastings" DROP COLUMN "takenMeals"`);
        await queryRunner.query(`ALTER TABLE "fastings" ADD "takenMeals" character varying array NOT NULL DEFAULT '{}'`);
        await queryRunner.query(`ALTER TYPE "public"."region_enum" RENAME TO "region_enum_old"`);
        await queryRunner.query(`CREATE TYPE "public"."users_region_enum" AS ENUM('sokra', 'sousse')`);
        await queryRunner.query(`ALTER TABLE "users" ALTER COLUMN "region" DROP DEFAULT`);
        await queryRunner.query(`ALTER TABLE "users" ALTER COLUMN "region" TYPE "public"."users_region_enum" USING "region"::"text"::"public"."users_region_enum"`);
        await queryRunner.query(`DROP TYPE "public"."region_enum_old"`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."region_enum_old" AS ENUM('sokra', 'sousse')`);
        await queryRunner.query(`ALTER TABLE "users" ALTER COLUMN "region" TYPE "public"."region_enum_old" USING "region"::"text"::"public"."region_enum_old"`);
        await queryRunner.query(`ALTER TABLE "users" ALTER COLUMN "region" SET DEFAULT 'sokra'`);
        await queryRunner.query(`DROP TYPE "public"."users_region_enum"`);
        await queryRunner.query(`ALTER TYPE "public"."region_enum_old" RENAME TO "region_enum"`);
        await queryRunner.query(`ALTER TABLE "fastings" DROP COLUMN "takenMeals"`);
        await queryRunner.query(`ALTER TABLE "fastings" ADD "takenMeals" date array DEFAULT ARRAY[]`);
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "lastTakenMeal" SET DEFAULT now()`);
        await queryRunner.query(`CREATE TYPE "public"."region_enum_old" AS ENUM('sokra', 'sousse')`);
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "region" TYPE "public"."region_enum_old" USING "region"::"text"::"public"."region_enum_old"`);
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "region" SET DEFAULT 'sokra'`);
        await queryRunner.query(`DROP TYPE "public"."fastings_region_enum"`);
        await queryRunner.query(`ALTER TYPE "public"."region_enum_old" RENAME TO "region_enum"`);
        await queryRunner.query(`ALTER TABLE "fastings" DROP CONSTRAINT "PK_20dd97bf45615e8f88763b9cd6b"`);
        await queryRunner.query(`ALTER TABLE "fastings" DROP COLUMN "comment"`);
        await queryRunner.query(`ALTER TABLE "fastings" DROP COLUMN "phone"`);
        await queryRunner.query(`ALTER TABLE "users" ADD CONSTRAINT "valid_region_enum" CHECK ((region = ANY (ARRAY['sokra'::region_enum, 'sousse'::region_enum])))`);
    }

}
