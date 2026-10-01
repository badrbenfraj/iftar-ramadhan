import { HttpStatus, INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';

import { AppModule } from '../../src/app.module';
import { VALIDATION_PIPE_OPTIONS } from '../../src/shared/constants';
import {
  closeDBAfterTest,
  createDBEntities,
  resetDBBeforeTest,
  seedRegion,
} from '../test-utils';

/**
 * The core business rule: one meal per person per day, enforced by the
 * server even when many devices confirm the same person at once.
 */
describe('Meal confirmation (e2e)', () => {
  let app: INestApplication;
  let token: string;
  let regionId: number;

  const auth = () => ({ Authorization: `Bearer ${token}` });

  const createPerson = (id: number, extra: Record<string, unknown> = {}) =>
    request(app.getHttpServer())
      .post('/fastings')
      .set(auth())
      .send({
        id,
        firstName: 'نجوى',
        lastName: 'شلبي',
        singleMeal: 1,
        familyMeal: 1,
        region: regionId,
        cameToday: false,
        ...extra,
      });

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

    await request(app.getHttpServer())
      .post('/auth/register')
      .send({
        name: 'Volunteer',
        username: 'volunteer',
        email: 'volunteer@example.com',
        password: 'volunteer-pass',
        region: { id: regionId },
      })
      .expect(HttpStatus.CREATED);

    const login = await request(app.getHttpServer())
      .post('/auth/login')
      .send({ username: 'volunteer', password: 'volunteer-pass' })
      .expect(HttpStatus.OK);
    token = login.body.data.accessToken;
  });

  it('never exposes the password hash in /users/me', async () => {
    const res = await request(app.getHttpServer())
      .get('/users/me')
      .set(auth())
      .expect(HttpStatus.OK);
    expect(res.body.data).not.toHaveProperty('password');
    expect(res.body.data.region.id).toBe(regionId);
  });

  it('rejects creating a person with an ID that already exists', async () => {
    await createPerson(10).expect(HttpStatus.CREATED);
    const res = await createPerson(10).expect(HttpStatus.CONFLICT);
    expect(res.body.error.details.code).toBe('PERSON_ID_TAKEN');
  });

  it('registers a person who came today with today as their only meal', async () => {
    const created = await createPerson(40, { cameToday: true }).expect(
      HttpStatus.CREATED,
    );
    expect(created.body.data.mealTakenToday).toBe(true);
    expect(created.body.data.takenMeals).toHaveLength(1);

    const confirm = await request(app.getHttpServer())
      .patch(`/fastings/confirm/${regionId}/40`)
      .set(auth())
      .send({})
      .expect(HttpStatus.CONFLICT);
    expect(confirm.body.error.details.code).toBe('MEAL_ALREADY_TAKEN');
  });

  it('confirms once, then rejects the same day with MEAL_ALREADY_TAKEN', async () => {
    await createPerson(20).expect(HttpStatus.CREATED);

    const before = await request(app.getHttpServer())
      .get(`/fastings/${regionId}/20`)
      .set(auth())
      .expect(HttpStatus.OK);
    expect(before.body.data.mealTakenToday).toBe(false);
    // Not having come today must not invent a meal.
    expect(before.body.data.lastTakenMeal).toBeNull();
    expect(before.body.data.takenMeals).toEqual([]);
    expect(before.body.data).not.toHaveProperty('createdBy');

    // Legacy clients send the full person with a stale history: ignored.
    const first = await request(app.getHttpServer())
      .patch(`/fastings/confirm/${regionId}/20`)
      .set(auth())
      .send({ ...before.body.data, takenMeals: [], comment: 'note' })
      .expect(HttpStatus.OK);
    expect(first.body.data.mealTakenToday).toBe(true);
    expect(first.body.data.takenMeals).toHaveLength(1);
    expect(first.body.data.comment).toBe('note');

    const second = await request(app.getHttpServer())
      .patch(`/fastings/confirm/${regionId}/20`)
      .set(auth())
      .send({})
      .expect(HttpStatus.CONFLICT);
    expect(second.body.error.details.code).toBe('MEAL_ALREADY_TAKEN');
  });

  it('allows exactly one of many concurrent confirmations', async () => {
    await createPerson(30).expect(HttpStatus.CREATED);

    const statuses = await Promise.all(
      Array.from({ length: 20 }, () =>
        request(app.getHttpServer())
          .patch(`/fastings/confirm/${regionId}/30`)
          .set(auth())
          .send({})
          .then((r) => r.status),
      ),
    );

    expect(statuses.filter((s) => s === HttpStatus.OK)).toHaveLength(1);
    expect(statuses.filter((s) => s === HttpStatus.CONFLICT)).toHaveLength(19);

    const after = await request(app.getHttpServer())
      .get(`/fastings/${regionId}/30`)
      .set(auth())
      .expect(HttpStatus.OK);
    // exactly one confirmation today, nothing recorded at registration
    expect(after.body.data.takenMeals).toHaveLength(1);
  });

  it('returns 404 for unknown persons and non-numeric (invalid QR) ids', async () => {
    await request(app.getHttpServer())
      .get(`/fastings/${regionId}/99999`)
      .set(auth())
      .expect(HttpStatus.NOT_FOUND);
    await request(app.getHttpServer())
      .patch(`/fastings/confirm/${regionId}/not-a-number`)
      .set(auth())
      .send({})
      .expect(HttpStatus.NOT_FOUND);
  });

  it('includes today in daily statistics', async () => {
    const today = new Date().toLocaleDateString('en-CA', {
      timeZone: 'Africa/Tunis',
    });
    const res = await request(app.getHttpServer())
      .get(`/fastings/statistics/${regionId}?start=${today}&end=${today}`)
      .set(auth())
      .expect(HttpStatus.OK);
    expect(res.body.data).toHaveLength(1);
    // persons 20, 30 and 40 collected today (1 single + 1 family×4 each)
    expect(res.body.data[0].statistics).toMatchObject({
      persons: 3,
      singleMeal: 3,
      familyMeal: 12,
      totalMeals: 15,
    });
  });

  it('does not count persons registered today in yesterday statistics', async () => {
    const yesterday = new Date(
      Date.now() - 24 * 60 * 60 * 1000,
    ).toLocaleDateString('en-CA', { timeZone: 'Africa/Tunis' });
    const res = await request(app.getHttpServer())
      .get(
        `/fastings/statistics/${regionId}?start=${yesterday}&end=${yesterday}`,
      )
      .set(auth())
      .expect(HttpStatus.OK);
    expect(res.body.data[0].statistics).toMatchObject({
      persons: 0,
      totalMeals: 0,
    });
  });

  afterAll(async () => {
    await app.close();
    await closeDBAfterTest();
  });
});
