import { Test, TestingModule } from '@nestjs/testing';

import { ROLE } from '../../auth/constants/role.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { CreateFastingInput } from '../dtos/fasting-input.dto';
import { FastingService } from '../services/fasting.service';
import { FastingController } from './fasting.controller';

describe('FastingController', () => {
  let controller: FastingController;

  const fastingService = { createFasting: jest.fn() };
  const logger = { setContext: jest.fn(), log: jest.fn() };

  const ctx = new RequestContext();
  ctx.user = { id: 7, username: 'vol', roles: [ROLE.USER] };

  const now = new Date('2025-03-05T17:30:00.000Z');

  const newPerson = (cameToday?: boolean): CreateFastingInput =>
    ({
      id: 42,
      firstName: 'Najwa',
      lastName: 'Chalbi',
      singleMeal: 2,
      familyMeal: 1,
      region: 1,
      cameToday,
    }) as CreateFastingInput;

  beforeEach(async () => {
    jest.clearAllMocks();
    const moduleRef: TestingModule = await Test.createTestingModule({
      controllers: [FastingController],
      providers: [
        { provide: FastingService, useValue: fastingService },
        { provide: AppLogger, useValue: logger },
      ],
    }).compile();
    controller = moduleRef.get(FastingController);

    jest.useFakeTimers({ now });
    fastingService.createFasting.mockResolvedValue({ id: 42 });
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  describe('createFasting', () => {
    it('records today as the first meal when the person came today', async () => {
      await controller.createFasting(ctx, newPerson(true));

      const [, input] = fastingService.createFasting.mock.calls[0];
      expect(input.lastTakenMeal).toEqual(now);
      expect(input.takenMeals).toEqual([now]);
    });

    it.each([
      ['did not come today', false],
      ['omits cameToday', undefined],
    ])(
      'records no meal when the person %s',
      async (_label, cameToday?: boolean) => {
        await controller.createFasting(ctx, newPerson(cameToday));

        const [, input] = fastingService.createFasting.mock.calls[0];
        expect(input.lastTakenMeal).toBeNull();
        expect(input.takenMeals).toEqual([]);
      },
    );

    it('ignores a meal history supplied by the client', async () => {
      await controller.createFasting(ctx, {
        ...newPerson(false),
        lastTakenMeal: new Date('2025-03-01T12:00:00.000Z'),
        takenMeals: [new Date('2025-03-01T12:00:00.000Z')],
      });

      const [, input] = fastingService.createFasting.mock.calls[0];
      expect(input.lastTakenMeal).toBeNull();
      expect(input.takenMeals).toEqual([]);
    });

    it('returns the created person', async () => {
      await expect(
        controller.createFasting(ctx, newPerson(true)),
      ).resolves.toEqual({ data: { id: 42 }, meta: {} });
    });
  });
});
