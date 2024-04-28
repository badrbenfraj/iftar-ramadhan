import { MigrationInterface, QueryRunner } from "typeorm";

export class Firsttimefasting1710347935837 implements MigrationInterface {
    name = 'Firsttimefasting1710347935837'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TABLE "fastings" ("id" SERIAL NOT NULL, "firstName" character varying NOT NULL, "lastName" character varying NOT NULL, "familyMeal" integer NOT NULL, "singleMeal" integer NOT NULL, "lastTakenMeal" TIMESTAMP NOT NULL DEFAULT now(), "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), "createdById" integer, CONSTRAINT "PK_33563b1cc12321877ca97148150" PRIMARY KEY ("id"))`);
        await queryRunner.query(`ALTER TABLE "fastings" ADD CONSTRAINT "FK_d5c2a453202bc367cc43bb0fa36" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "fastings" DROP CONSTRAINT "FK_d5c2a453202bc367cc43bb0fa36"`);
        await queryRunner.query(`DROP TABLE "fastings"`);
    }

}
