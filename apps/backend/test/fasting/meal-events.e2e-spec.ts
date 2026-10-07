import { HttpStatus, INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { randomUUID } from 'crypto';
import request from 'supertest';

import { AppModule } from '../../src/app.module';
import { VALIDATION_PIPE_OPTIONS } from '../../src/shared/constants';
import {
  closeDBAfterTest,
  createDBEntities,
  dbQuery,
  resetDBBeforeTest,
  seedAdminUser,
  seedRegion,
} from '../test-utils';

/** Spec 2A: meal events, idempotent confirm, served-by and undo. */
describe('Meal events (e2e)', () => {
  let app: INestApplication;
  let regionId: number;
  let volunteer: string;
  let other: string;
  // Used by the revoke tests added in Task 4.
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  let admin: string;

  const server = () => app.getHttpServer();
  const bearer = (token: string) => ({ Authorization: `Bearer ${token}` });

  const signUp = async (username: string, name: string): Promise<string> => {
    await request(server())
      .post('/auth/register')
      .send({
        name,
        username,
        email: `${username}@example.com`,
        password: `${username}-pass`,
        region: { id: regionId },
      })
      .expect(HttpStatus.CREATED);
    const login = await request(server())
      .post('/auth/login')
      .send({ username, password: `${username}-pass` })
      .expect(HttpStatus.OK);
    return login.body.data.accessToken;
  };

  const createPerson = (id: number, extra: Record<string, unknown> = {}) =>
    request(server())
      .post('/fastings')
      .set(bearer(volunteer))
      .send({
        id,
        firstName: 'Najwa',
        lastName: 'Chalbi',
        singleMeal: 1,
        familyMeal: 1,
        region: regionId,
        cameToday: false,
        ...extra,
      })
      .expect(HttpStatus.CREATED);

  const confirm = (
    id: number,
    body: Record<string, unknown> = {},
    token = volunteer,
  ) =>
    request(server())
      .patch(`/fastings/confirm/${regionId}/${id}`)
      .set(bearer(token))
      .send(body);

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const revoke = (eventId: string, token = volunteer) =>
    request(server())
      .post(`/fastings/meals/${eventId}/revoke`)
      .set(bearer(token))
      .send();

  const activeMeals = async (fastingId: number): Promise<number> => {
    const [row] = await dbQuery<{ n: string }>(
      `SELECT count(*) AS "n" FROM "meal_events"
       WHERE "fastingId" = $1 AND "revokedAt" IS NULL AND "conflict" = false`,
      [fastingId],
    );
    return Number(row.n);
  };

  beforeAll(async () => {
    await resetDBBeforeTest();
    await createDBEntities();
    regionId = (await seedRegion()).id;
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(new ValidationPipe(VALIDATION_PIPE_OPTIONS));
    await app.init();
    volunteer = await signUp('volunteer', 'Volunteer');
    other = await signUp('other', 'Other Volunteer');
    admin = (await seedAdminUser(app)).authTokenForAdmin.accessToken;
  });

  describe('confirm', () => {
    it('answers a retry of the same clientEventId with the same meal, recorded once', async () => {
      await createPerson(101);
      const clientEventId = randomUUID();
      const first = await confirm(101, { clientEventId }).expect(HttpStatus.OK);
      const retry = await confirm(101, { clientEventId }).expect(HttpStatus.OK);

      expect(first.body.data.meal.eventId).toBe(clientEventId);
      expect(retry.body.data.meal.eventId).toBe(clientEventId);
      expect(first.body.data.meal.servedBy).toEqual({
        id: expect.any(Number),
        name: 'Volunteer',
      });
      expect(retry.body.data.takenMeals).toHaveLength(1);
      expect(await activeMeals(101)).toBe(1);
    });

    it('rejects a clientEventId already used for another person', async () => {
      await createPerson(102);
      await createPerson(103);
      const clientEventId = randomUUID();
      await confirm(102, { clientEventId }).expect(HttpStatus.OK);
      const res = await confirm(103, { clientEventId }).expect(
        HttpStatus.UNPROCESSABLE_ENTITY,
      );
      expect(res.body.error.details.code).toBe('CLIENT_EVENT_ID_REUSED');
      expect(await activeMeals(103)).toBe(0);
    });

    it('says when and by whom on a second meal, and keeps the legacy field', async () => {
      await createPerson(104);
      await confirm(104, { clientEventId: randomUUID() }).expect(HttpStatus.OK);
      const res = await confirm(104, { clientEventId: randomUUID() }, other).expect(
        HttpStatus.CONFLICT,
      );
      const details = res.body.error.details;
      expect(details.code).toBe('MEAL_ALREADY_TAKEN');
      expect(details.servedBy.name).toBe('Volunteer');
      expect(typeof details.servedAt).toBe('string');
      expect(details.lastTakenMeal).toBe(details.servedAt);
    });

    it('lets exactly one of many concurrent confirms with different IDs win', async () => {
      await createPerson(105);
      const statuses = await Promise.all(
        Array.from({ length: 10 }, () =>
          confirm(105, { clientEventId: randomUUID() }).then((r) => r.status),
        ),
      );
      expect(statuses.filter((s) => s === HttpStatus.OK)).toHaveLength(1);
      expect(statuses.filter((s) => s === HttpStatus.CONFLICT)).toHaveLength(9);
      expect(await activeMeals(105)).toBe(1);
    });

    it('answers concurrent retries of one clientEventId with the same meal', async () => {
      await createPerson(106);
      const clientEventId = randomUUID();
      const responses = await Promise.all(
        Array.from({ length: 5 }, () => confirm(106, { clientEventId })),
      );
      expect(responses.map((r) => r.status)).toEqual(Array(5).fill(HttpStatus.OK));
      expect(new Set(responses.map((r) => r.body.data.meal.eventId))).toEqual(
        new Set([clientEventId]),
      );
      expect(await activeMeals(106)).toBe(1);
    });

    it('stores the device ID sent with the confirm', async () => {
      await createPerson(107);
      const clientEventId = randomUUID();
      await confirm(107, { clientEventId, deviceId: 'inst-test' }).expect(HttpStatus.OK);
      const [row] = await dbQuery(
        `SELECT "deviceId", "source" FROM "meal_events" WHERE "id" = $1`,
        [clientEventId],
      );
      expect(row).toEqual({ deviceId: 'inst-test', source: 'online' });
    });

    it('rejects a malformed clientEventId', async () => {
      await createPerson(108);
      await confirm(108, { clientEventId: 'not-a-uuid' }).expect(HttpStatus.BAD_REQUEST);
    });
  });

  afterAll(async () => {
    await app.close();
    await closeDBAfterTest();
  });
});
