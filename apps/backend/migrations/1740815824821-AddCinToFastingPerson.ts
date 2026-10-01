import { MigrationInterface, QueryRunner } from "typeorm";

export class AddCinToFastingPerson1740815824821 implements MigrationInterface {
    name = 'AddCinToFastingPerson1740815824821'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "fastings" ADD "cin" character varying`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "fastings" DROP COLUMN "cin"`);
    }

}
