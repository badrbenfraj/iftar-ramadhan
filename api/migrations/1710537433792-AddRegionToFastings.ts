import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddRegionToFastings1710537433792 implements MigrationInterface {
    name = 'AddRegionToFastings1710537433792';

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(
            `ALTER TABLE "fastings" ADD COLUMN "region" ENUM('sokra', 'sousse') NOT NULL DEFAULT 'sokra'`,
        );
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "fastings" DROP COLUMN "region"`);
    }
}
