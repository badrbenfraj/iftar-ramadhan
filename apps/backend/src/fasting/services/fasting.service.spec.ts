import { ConflictException, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';

import { ROLE } from '../../auth/constants/role.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { UserService } from '../../user/services/user.service';
import { FastingRepository } from '../repositories/fasting.repository';
import { FASTING_ERROR_CODES, FastingService } from './fasting.service';
import { FastingAclService } from './fasting-acl.service';

describe('FastingService', () => {
  let service: FastingService;

  const manager = {
    query: jest.fn(),
    findOne: jest.fn(),
  };

  const repository = {
    manager: {
      transaction: jest.fn(async (work: (m: typeof manager) => unknown) =>
        work(manager),
      ),
    },
    findOne: jest.fn(),
    save: jest.fn(),
    getByIdAndRegion: jest.fn(),
    getFastingsByRegion: jest.fn(),
  };

  const userService = { getUserById: jest.fn() };
  const config = { get: jest.fn(() => 'Africa/Tunis') };
  const logger = { setContext: jest.fn(), log: jest.fn() };

  const ctx = new RequestContext();
  ctx.user = { id: 7, username: 'vol', roles: [ROLE.USER] };

  const person = {
    id: 42,
    firstName: 'Najwa',
    lastName: 'Chalbi',
    singleMeal: 2,
    familyMeal: 1,
    takenMeals: [],
    lastTakenMeal: new Date('2020-01-01T12:00:00Z'),
    region: { id: 1, name: 'Dar Sokra' },
    createdBy: { id: 7, password: 'hash' },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const moduleRef: TestingModule = await Test.createTestingModule({
      providers: [
        FastingService,
        FastingAclService,
        { provide: FastingRepository, useValue: repository },
        { provide: UserService, useValue: userService },
        { provide: ConfigService, useValue: config },
        { provide: AppLogger, useValue: logger },
      ],
    }).compile();
    service = moduleRef.get(FastingService);
  });

  describe('confirmMeal', () => {
    it('records the meal when the person has not collected today', async () => {
      manager.query
        .mockResolvedValueOnce([
          { id: 42, lastTakenMeal: new Date('2020-01-01T12:00:00Z') },
        ])
        .mockResolvedValueOnce(undefined);
      manager.findOne.mockResolvedValue(person);
      repository.getByIdAndRegion.mockResolvedValue({
        ...person,
        lastTakenMeal: new Date(),
      });

      const result = await service.confirmMeal(ctx, 42, 1, { phone: '123' });

      // The lock is taken first, in the same transaction as the update.
      expect(manager.query.mock.calls[0][0]).toContain('FOR UPDATE');
      const [updateSql, params] = manager.query.mock.calls[1];
      expect(updateSql).toContain('array_append("takenMeals"');
      expect(params.slice(0, 2)).toEqual([42, 1]);
      expect(params[4]).toBe(true); // phone provided
      expect(params[5]).toBe('123');
      expect(params[6]).toBe(false); // comment untouched
      expect(result.mealTakenToday).toBe(true);
      expect(result).not.toHaveProperty('createdBy');
    });

    it('records the first meal of a person who has never collected one', async () => {
      manager.query
        .mockResolvedValueOnce([{ id: 42, lastTakenMeal: null }])
        .mockResolvedValueOnce(undefined);
      manager.findOne.mockResolvedValue({ ...person, lastTakenMeal: null });
      repository.getByIdAndRegion.mockResolvedValue({
        ...person,
        lastTakenMeal: new Date(),
        takenMeals: [new Date().toISOString()],
      });

      const result = await service.confirmMeal(ctx, 42, 1, {});

      expect(manager.query).toHaveBeenCalledTimes(2);
      expect(manager.query.mock.calls[1][0]).toContain('UPDATE "fastings"');
      expect(result.mealTakenToday).toBe(true);
    });

    it('rejects a second collection on the same day with MEAL_ALREADY_TAKEN', async () => {
      manager.query.mockResolvedValueOnce([
        { id: 42, lastTakenMeal: new Date() },
      ]);
      manager.findOne.mockResolvedValue(person);

      const error = await service.confirmMeal(ctx, 42, 1, {}).catch((e) => e);

      expect(error).toBeInstanceOf(ConflictException);
      expect(error.getResponse()).toMatchObject({
        code: FASTING_ERROR_CODES.MEAL_ALREADY_TAKEN,
      });
      expect(manager.query).toHaveBeenCalledTimes(1); // no UPDATE issued
    });

    it('returns 404 for an unknown person', async () => {
      manager.query.mockResolvedValueOnce([]);

      await expect(service.confirmMeal(ctx, 999, 1, {})).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    it('returns 404 for a non-numeric id (invalid QR) without hitting the DB', async () => {
      await expect(
        service.confirmMeal(ctx, Number('abc'), 1, {}),
      ).rejects.toBeInstanceOf(NotFoundException);
      expect(repository.manager.transaction).not.toHaveBeenCalled();
    });
  });

  describe('createFasting', () => {
    it('refuses to overwrite an existing person ID', async () => {
      userService.getUserById.mockResolvedValue({ id: 7, region: { id: 1 } });
      repository.findOne.mockResolvedValue(person);

      const error = await service
        .createFasting(ctx, {
          id: 42,
          firstName: 'X',
          lastName: 'Y',
          singleMeal: 1,
          familyMeal: 0,
          region: 1,
        } as any)
        .catch((e) => e);

      expect(error).toBeInstanceOf(ConflictException);
      expect(error.getResponse()).toMatchObject({
        code: FASTING_ERROR_CODES.PERSON_ID_TAKEN,
      });
      expect(repository.save).not.toHaveBeenCalled();
    });

    it('saves a person with no meal history as not collected today', async () => {
      userService.getUserById.mockResolvedValue({ id: 7, region: { id: 1 } });
      repository.findOne.mockResolvedValue(null);
      repository.save.mockImplementation(async (fasting) => fasting);

      const result = await service.createFasting(ctx, {
        id: 43,
        firstName: 'X',
        lastName: 'Y',
        singleMeal: 1,
        familyMeal: 0,
        region: 1,
        lastTakenMeal: null,
        takenMeals: [],
      } as any);

      expect(repository.save).toHaveBeenCalledWith(
        expect.objectContaining({ lastTakenMeal: null, takenMeals: [] }),
      );
      expect(result.lastTakenMeal).toBeNull();
      expect(result.takenMeals).toEqual([]);
      expect(result.mealTakenToday).toBe(false);
    });
  });

  describe('getStatistics', () => {
    it('buckets by Tunis day, includes the end day, and counts a family meal as 4', async () => {
      repository.getFastingsByRegion.mockResolvedValue([
        [
          {
            ...person,
            singleMeal: 1,
            familyMeal: 2,
            // 23:30 UTC on Mar 2 == Mar 3 in Tunis; duplicated entry counts once.
            takenMeals: [
              '2025-03-02T23:30:00.000Z',
              '2025-03-03T18:00:00.000Z',
              '2025-03-05T18:00:00.000Z',
            ],
          },
        ],
        10,
      ]);

      const stats = await service.getStatistics(
        ctx,
        1,
        'Mon Mar 03 2025',
        '2025-03-05',
      );

      expect(stats.map((s) => s.date)).toEqual([
        'Mon Mar 03 2025',
        'Tue Mar 04 2025',
        'Wed Mar 05 2025',
      ]);
      expect(stats[0].statistics).toEqual({
        totalPersons: 10,
        persons: 1,
        singleMeal: 1,
        familyMeal: 8,
        totalMeals: 9,
      });
      expect(stats[1].statistics.persons).toBe(0);
      expect(stats[2].statistics.persons).toBe(1);
    });

    it('counts a person who has never collected a meal on no day', async () => {
      repository.getFastingsByRegion.mockResolvedValue([
        [
          {
            ...person,
            lastTakenMeal: null,
            takenMeals: [],
            createdAt: new Date('2025-03-04T18:00:00.000Z'),
          },
        ],
        1,
      ]);

      const stats = await service.getStatistics(
        ctx,
        1,
        '2025-03-03',
        '2025-03-04',
      );

      expect(stats.map((s) => s.statistics)).toEqual([
        {
          totalPersons: 1,
          persons: 0,
          singleMeal: 0,
          familyMeal: 0,
          totalMeals: 0,
        },
        {
          totalPersons: 1,
          persons: 0,
          singleMeal: 0,
          familyMeal: 0,
          totalMeals: 0,
        },
      ]);
    });
  });
});
