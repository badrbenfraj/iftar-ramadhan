import { MigrationInterface, QueryRunner } from "typeorm";

/**
 * A person registered without collecting a meal ("came today" unchecked) has
 * no last meal. Previously a fake meal dated yesterday was stored instead.
 */
export class MakeLastTakenMealNullable1790850000000 implements MigrationInterface {
    name = 'MakeLastTakenMealNullable1790850000000'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "lastTakenMeal" DROP NOT NULL`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        // Restore the legacy placeholder (the day before registration) so the
        // NOT NULL constraint can be re-applied. The meal history is untouched.
        await queryRunner.query(`UPDATE "fastings" SET "lastTakenMeal" = "createdAt" - interval '1 day' WHERE "lastTakenMeal" IS NULL`);
        await queryRunner.query(`ALTER TABLE "fastings" ALTER COLUMN "lastTakenMeal" SET NOT NULL`);
    }

}
