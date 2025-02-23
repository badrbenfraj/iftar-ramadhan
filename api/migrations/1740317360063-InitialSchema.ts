import { MigrationInterface, QueryRunner } from "typeorm";

export class InitialSchema1740317360063 implements MigrationInterface {
    name = 'InitialSchema1740317360063'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TABLE "fastings" ("id" integer NOT NULL, "firstName" character varying NOT NULL, "lastName" character varying NOT NULL, "phone" character varying, "comment" text, "familyMeal" integer NOT NULL, "singleMeal" integer NOT NULL, "lastTakenMeal" TIMESTAMP NOT NULL, "takenMeals" character varying array NOT NULL DEFAULT '{}', "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), "regionId" integer, "regionName" character varying, "createdById" integer, CONSTRAINT "PK_33563b1cc12321877ca97148150" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "regions" ("id" SERIAL NOT NULL, "name" character varying NOT NULL, "active" boolean NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), "createdBy" integer, CONSTRAINT "PK_9f226d15922ffd0b2a95f73a6b3" PRIMARY KEY ("id", "name"))`);
        await queryRunner.query(`CREATE TABLE "users" ("id" SERIAL NOT NULL, "name" character varying(100) NOT NULL, "password" character varying NOT NULL, "username" character varying(200) NOT NULL, "roles" text NOT NULL, "isAccountDisabled" boolean NOT NULL, "email" character varying(200) NOT NULL, "createdAt" TIMESTAMP DEFAULT now(), "updatedAt" TIMESTAMP DEFAULT now(), "regionId" integer, "regionName" character varying, CONSTRAINT "username" UNIQUE ("username"), CONSTRAINT "email" UNIQUE ("email"), CONSTRAINT "PK_a3ffb1c0c8416b9fc6f907b7433" PRIMARY KEY ("id"))`);
        await queryRunner.query(`ALTER TABLE "fastings" ADD CONSTRAINT "FK_18d2034cb39130e79816e075880" FOREIGN KEY ("regionId", "regionName") REFERENCES "regions"("id","name") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "fastings" ADD CONSTRAINT "FK_d5c2a453202bc367cc43bb0fa36" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "regions" ADD CONSTRAINT "FK_41a79dcc30887a99adb42fbe6c4" FOREIGN KEY ("createdBy") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "users" ADD CONSTRAINT "FK_a1aa37f135c5949cfde6825546a" FOREIGN KEY ("regionId", "regionName") REFERENCES "regions"("id","name") ON DELETE NO ACTION ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "users" DROP CONSTRAINT "FK_a1aa37f135c5949cfde6825546a"`);
        await queryRunner.query(`ALTER TABLE "regions" DROP CONSTRAINT "FK_41a79dcc30887a99adb42fbe6c4"`);
        await queryRunner.query(`ALTER TABLE "fastings" DROP CONSTRAINT "FK_d5c2a453202bc367cc43bb0fa36"`);
        await queryRunner.query(`ALTER TABLE "fastings" DROP CONSTRAINT "FK_18d2034cb39130e79816e075880"`);
        await queryRunner.query(`DROP TABLE "users"`);
        await queryRunner.query(`DROP TABLE "regions"`);
        await queryRunner.query(`DROP TABLE "fastings"`);
    }

}
