import { HttpStatus, INestApplication } from '@nestjs/common';
import request from 'supertest';
import { DataSource } from 'typeorm';

import { ROLE } from '../src/auth/constants/role.constant';
import { LoginInput } from '../src/auth/dtos/auth-login-input.dto';
import { AuthTokenOutput } from '../src/auth/dtos/auth-token-output.dto';
import { Region } from '../src/region/entities/region.entity';
import { RequestContext } from '../src/shared/request-context/request-context.dto';
import { CreateUserInput } from '../src/user/dtos/user-create-input.dto';
import { UserOutput } from '../src/user/dtos/user-output.dto';
import { UserService } from '../src/user/services/user.service';

export const TEST_DB_NAME = process.env.E2E_DB_NAME || 'e2e_test_db';

export const connectionOptions = {
  type: 'postgres' as const,
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  username: process.env.DB_USER || 'root',
  password: process.env.DB_PASS || 'example',
};

let entitiesDataSource: DataSource | undefined;

export const resetDBBeforeTest = async (): Promise<void> => {
  // This overwrites the DB_NAME used in the SharedModule's TypeORM init.
  // All the tests will run against the e2e db due to this overwrite.
  process.env.DB_NAME = TEST_DB_NAME;

  const admin = new DataSource({ ...connectionOptions, database: 'postgres' });
  await admin.initialize();
  await admin.query(`drop database if exists ${TEST_DB_NAME} with (force)`);
  await admin.query(`create database ${TEST_DB_NAME}`);
  await admin.destroy();
};

export const createDBEntities = async (): Promise<void> => {
  entitiesDataSource = new DataSource({
    ...connectionOptions,
    database: TEST_DB_NAME,
    entities: [__dirname + '/../src/**/*.entity{.ts,.js}'],
    synchronize: true,
  });
  await entitiesDataSource.initialize();
};

export const seedRegion = async (name = 'Dar Sokra'): Promise<Region> => {
  const repo = entitiesDataSource.getRepository(Region);
  return repo.save(repo.create({ name, active: true }));
};

export const seedAdminUser = async (
  app: INestApplication,
): Promise<{ adminUser: UserOutput; authTokenForAdmin: AuthTokenOutput }> => {
  const defaultAdmin: CreateUserInput = {
    name: 'Default Admin User',
    username: 'default-admin',
    password: 'default-admin-password',
    roles: [ROLE.ADMIN],
    isAccountDisabled: false,
    email: 'default-admin@example.com',
  };

  const ctx = new RequestContext();

  // Creating Admin User
  const userService = app.get(UserService);
  const userOutput = await userService.createUser(ctx, defaultAdmin);

  const loginInput: LoginInput = {
    username: defaultAdmin.username,
    password: defaultAdmin.password,
  };

  // Logging in Admin User to get AuthToken
  const loginResponse = await request(app.getHttpServer())
    .post('/auth/login')
    .send(loginInput)
    .expect(HttpStatus.OK);

  const authTokenForAdmin: AuthTokenOutput = loginResponse.body.data;

  const adminUser: UserOutput = JSON.parse(JSON.stringify(userOutput));

  return { adminUser, authTokenForAdmin };
};

export const closeDBAfterTest = async (): Promise<void> => {
  await entitiesDataSource?.destroy();
  entitiesDataSource = undefined;
};

/** Raw SQL against the e2e database (set up by createDBEntities). */
export const dbQuery = <T = any>(
  sql: string,
  params: unknown[] = [],
): Promise<T[]> => entitiesDataSource.query(sql, params);
