import { ConflictException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test, TestingModule } from '@nestjs/testing';

import { ROLE } from '../../auth/constants/role.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { UserService } from '../../user/services/user.service';
import { FastingRepository } from '../repositories/fasting.repository';
import { FASTING_ERROR_CODES, FastingService } from './fasting.service';
import { FastingAclService } from './fasting-acl.service';
import { MealEventService } from './meal-event.service';

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

  const meals = {
    confirm: jest.fn(),
    todayMealsByRegion: jest.fn(async () => new Map()),
    todayMealOf: jest.fn(async () => null),
    mealsOf: jest.fn(async () => []),
    recordRegistrationMeal: jest.fn(),
    revoke: jest.fn(),
  };

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
        { provide: MealEventService, useValue: meals },
        { provide: UserService, useValue: userService },
        { provide: ConfigService, useValue: config },
        { provide: AppLogger, useValue: logger },
      ],
    }).compile();
    service = moduleRef.get(FastingService);
  });

  describe('confirmMeal', () => {
    it('returns the person with the meal the request recorded', async () => {
      const meal = {
        eventId: '6f1c2c55-7a8e-4d39-9b0e-6c7c1f0a9d11',
        servedAt: new Date().toISOString(),
        servedBy: { id: 7, name: 'Vol' },
        revokedAt: null,
      };
      meals.confirm.mockResolvedValue(meal);
      repository.getByIdAndRegion.mockResolvedValue({
        ...person,
        lastTakenMeal: new Date(),
      });

      const result = await service.confirmMeal(ctx, 42, 1, { phone: '123' });

      expect(meals.confirm).toHaveBeenCalledWith(ctx, 42, 1, { phone: '123' });
      expect(result.meal).toEqual(meal);
      expect(result.todayMeal).toEqual(meal);
      expect(result.mealTakenToday).toBe(true);
      expect(result).not.toHaveProperty('createdBy');
    });

    it('has no meal tonight when the replayed meal was undone', async () => {
      meals.confirm.mockResolvedValue({
        eventId: '6f1c2c55-7a8e-4d39-9b0e-6c7c1f0a9d11',
        servedAt: new Date().toISOString(),
        servedBy: { id: 7, name: 'Vol' },
        revokedAt: new Date().toISOString(),
      });
      repository.getByIdAndRegion.mockResolvedValue({
        ...person,
        lastTakenMeal: null,
      });

      const result = await service.confirmMeal(ctx, 42, 1, {});

      expect(result.todayMeal).toBeNull();
      expect(result.mealTakenToday).toBe(false);
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
