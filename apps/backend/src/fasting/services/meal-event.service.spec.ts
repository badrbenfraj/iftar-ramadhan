import { NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import { DataSource } from 'typeorm';

import { ROLE } from '../../auth/constants/role.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { FastingAclService } from './fasting-acl.service';
import { MealEventService, toMealEventOutput } from './meal-event.service';

describe('MealEventService', () => {
  let service: MealEventService;
  const dataSource = { transaction: jest.fn() };
  const ctx = new RequestContext();
  ctx.user = { id: 7, username: 'vol', roles: [ROLE.USER] };

  beforeEach(async () => {
    jest.clearAllMocks();
    const moduleRef = await Test.createTestingModule({
      providers: [
        MealEventService,
        FastingAclService,
        { provide: DataSource, useValue: dataSource },
        { provide: ConfigService, useValue: { get: jest.fn(() => 'Africa/Tunis') } },
        { provide: AppLogger, useValue: { setContext: jest.fn(), log: jest.fn() } },
      ],
    }).compile();
    service = moduleRef.get(MealEventService);
  });

  it('returns 404 for a non-numeric id (invalid QR) without opening a transaction', async () => {
    await expect(
      service.confirm(ctx, Number('abc'), 1, {}),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(dataSource.transaction).not.toHaveBeenCalled();
  });

  it('computes the service day in APP_TIMEZONE across midnight', () => {
    // 22:59 UTC = 23:59 Tunis; 23:01 UTC = 00:01 the next day in Tunis.
    expect(service.serviceDay(new Date('2027-02-21T22:59:00Z'))).toBe('2027-02-21');
    expect(service.serviceDay(new Date('2027-02-21T23:01:00Z'))).toBe('2027-02-22');
  });

  it('maps a row to the API shape, with no volunteer for backfilled history', () => {
    const base = {
      eventId: 'e',
      fastingId: 1,
      regionId: 1,
      servedAt: new Date('2027-02-21T17:44:10Z'),
      receivedAt: new Date('2027-02-21T17:44:10Z'),
      serviceDay: '2027-02-21',
      conflict: false,
      revokedAt: null,
    };
    expect(
      toMealEventOutput({ ...base, servedByUserId: 3, servedByName: 'Sami' }),
    ).toEqual({
      eventId: 'e',
      servedAt: '2027-02-21T17:44:10.000Z',
      servedBy: { id: 3, name: 'Sami' },
      revokedAt: null,
    });
    expect(
      toMealEventOutput({ ...base, servedByUserId: null, servedByName: null })
        .servedBy,
    ).toBeNull();
  });
});
