import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { plainToClass } from 'class-transformer';
import { QueryDeepPartialEntity } from 'typeorm/query-builder/QueryPartialEntity';

import { Region } from '../../region/entities/region.entity';
import { Action } from '../../shared/acl/action.constant';
import { Actor } from '../../shared/acl/actor.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import {
  dayKeyToLabel,
  DEFAULT_APP_TIMEZONE,
  enumerateDayKeys,
  isSameLocalDay,
  localDayKey,
  parseDayKey,
} from '../../shared/utils/local-day';
import { User } from '../../user/entities/user.entity';
import { UserService } from '../../user/services/user.service';
import { FASTING_ERROR_CODES } from '../constants/error-codes';
import {
  ConfirmMealInput,
  CreateFastingInput,
  UpdateFastingInput,
} from '../dtos/fasting-input.dto';
import { FastingOutput } from '../dtos/fasting-output.dto';
import { MealEventOutput } from '../dtos/meal-event-output.dto';
import {
  MealSyncResultOutput,
  SyncMealEventInput,
} from '../dtos/meal-sync.dto';
import { Fasting } from '../entities/fasting.entity';
import { FastingRepository } from '../repositories/fasting.repository';
import { FastingAclService } from './fasting-acl.service';
import { MealEventService } from './meal-event.service';

export { FASTING_ERROR_CODES };

/** A family meal is served as four portions. */
export const FAMILY_MEAL_PORTIONS = 4;

export interface DailyStatistics {
  date: string;
  statistics: {
    totalPersons: number;
    persons: number;
    singleMeal: number;
    familyMeal: number;
    totalMeals: number;
  };
}

@Injectable()
export class FastingService {
  constructor(
    private repository: FastingRepository,
    private userService: UserService,
    private aclService: FastingAclService,
    private meals: MealEventService,
    private configService: ConfigService,
    private readonly logger: AppLogger,
  ) {
    this.logger.setContext(FastingService.name);
  }

  private get timeZone(): string {
    return this.configService.get<string>('timezone') || DEFAULT_APP_TIMEZONE;
  }

  /**
   * Builds the API representation of a person. `createdBy` is dropped on
   * purpose: it is an eager relation that would otherwise leak the creator's
   * user record (including the password hash) to every client.
   */
  private toOutput(
    fasting: Fasting,
    extras: {
      meal?: MealEventOutput;
      todayMeal?: MealEventOutput | null;
      meals?: MealEventOutput[];
    } = {},
  ): FastingOutput {
    const { createdBy, ...rest } = fasting;
    return plainToClass(FastingOutput, {
      ...rest,
      mealTakenToday: isSameLocalDay(
        fasting.lastTakenMeal ? new Date(fasting.lastTakenMeal) : null,
        new Date(),
        this.timeZone,
      ),
      ...extras,
    });
  }

  async createFasting(
    ctx: RequestContext,
    input: CreateFastingInput,
  ): Promise<FastingOutput> {
    this.logger.log(ctx, `${this.createFasting.name} was called`);
    const fasting = plainToClass(Fasting, input);

    const actor: Actor = ctx.user;

    const user = await this.userService.getUserById(ctx, actor.id);

    const isAllowed = this.aclService
      .forActor(actor)
      .canDoAction(Action.Create, fasting);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    // IDs are chosen by volunteers (printed on the QR card). `save()` would
    // silently overwrite an existing person with the same primary key.
    const existing = await this.repository.findOne({
      where: { id: input.id },
    });
    if (existing) {
      throw new ConflictException({
        message: `A person with ID ${input.id} already exists`,
        code: FASTING_ERROR_CODES.PERSON_ID_TAKEN,
      });
    }

    fasting.createdBy = plainToClass(User, user);
    fasting.region = plainToClass(Region, user.region);

    this.logger.log(ctx, `calling ${FastingRepository.name}.save`);
    const savedFasting = await this.repository.manager.transaction(
      async (manager) => {
        const saved = await manager.save(Fasting, fasting);
        if (saved.lastTakenMeal && fasting.region?.id != null) {
          await this.meals.recordRegistrationMeal(manager, {
            fastingId: saved.id,
            regionId: fasting.region.id,
            servedAt: new Date(saved.lastTakenMeal),
            servedByUserId: actor.id,
          });
        }
        return saved;
      },
    );

    const todayMeal = savedFasting.lastTakenMeal
      ? await this.meals.todayMealOf(savedFasting.id)
      : null;
    return this.toOutput(savedFasting, { todayMeal });
  }

  async getFastingsByRegion(
    ctx: RequestContext,
    region: number,
    limit: number,
    offset: number,
  ): Promise<{ fastings: FastingOutput[]; count: number }> {
    this.logger.log(ctx, `${this.getFastings.name} was called`);

    const actor: Actor = ctx.user;

    const isAllowed = this.aclService.forActor(actor).canDoAction(Action.List);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    this.logger.log(ctx, `calling ${FastingRepository.name}.findAndCount`);

    const [fastings, count] = await this.repository.getFastingsByRegion(
      region,
      limit,
      offset,
    );

    const today = await this.meals.todayMealsByRegion(region);
    return {
      fastings: fastings.map((f) =>
        this.toOutput(f, { todayMeal: today.get(f.id) ?? null }),
      ),
      count,
    };
  }

  async getFastings(
    ctx: RequestContext,
    limit: number,
    offset: number,
  ): Promise<{ fastings: FastingOutput[]; count: number }> {
    this.logger.log(ctx, `${this.getFastings.name} was called`);

    const actor: Actor = ctx.user;

    const isAllowed = this.aclService.forActor(actor).canDoAction(Action.List);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    this.logger.log(ctx, `calling ${FastingRepository.name}.findAndCount`);
    const [fastings, count] = await this.repository.findAndCount({
      where: {},
      take: limit,
      skip: offset,
    });

    return { fastings: fastings.map((f) => this.toOutput(f)), count };
  }

  async getFastingById(
    ctx: RequestContext,
    id: number,
    region: number,
  ): Promise<FastingOutput> {
    this.logger.log(ctx, `${this.getFastingById.name} was called`);

    const actor: Actor = ctx.user;

    this.logger.log(ctx, `calling ${FastingRepository.name}.getByIdAndRegion`);
    const fasting = await this.repository.getByIdAndRegion(id, region);

    const isAllowed = this.aclService
      .forActor(actor)
      .canDoAction(Action.Read, fasting);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    const meals = await this.meals.mealsOf(fasting.id);
    const todayMeal = await this.meals.todayMealOf(fasting.id);
    return this.toOutput(fasting, { todayMeal, meals });
  }

  async updateFasting(
    ctx: RequestContext,
    fastingId: number,
    region: number,
    input: UpdateFastingInput,
  ): Promise<FastingOutput> {
    this.logger.log(ctx, `${this.updateFasting.name} was called`);

    this.logger.log(ctx, `calling ${FastingRepository.name}.getByIdAndRegion`);
    const fasting = await this.repository.getByIdAndRegion(fastingId, region);

    const actor: Actor = ctx.user;

    const isAllowed = this.aclService
      .forActor(actor)
      .canDoAction(Action.Update, fasting);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    // The meal history is owned by the confirm endpoint; a regular edit must
    // not be able to rewrite or reset it with stale client data.

    const { lastTakenMeal, takenMeals, ...editable } = input;

    // Write only the editable columns: a full save would put back the stale
    // takenMeals / lastTakenMeal loaded above, dropping a concurrent confirm.
    const edits = plainToClass(Fasting, editable);
    const columns: QueryDeepPartialEntity<Fasting> = {
      firstName: edits.firstName,
      lastName: edits.lastName,
      cin: edits.cin,
      phone: edits.phone,
      comment: edits.comment,
      singleMeal: edits.singleMeal,
      familyMeal: edits.familyMeal,
    };
    if (edits.region !== undefined) columns.region = edits.region;

    this.logger.log(ctx, `calling ${FastingRepository.name}.update`);
    await this.repository.update({ id: fasting.id }, columns);
    const savedFasting = await this.repository.getByIdAndRegion(
      fastingId,
      region,
    );

    const todayMeal = await this.meals.todayMealOf(savedFasting.id);
    return this.toOutput(savedFasting, { todayMeal });
  }

  /**
   * Records today's meal (spec 2A §4.1); see MealEventService.confirm for the
   * one-meal-per-day and retry rules.
   */
  async confirmMeal(
    ctx: RequestContext,
    fastingId: number,
    region: number,
    input: ConfirmMealInput,
  ): Promise<FastingOutput> {
    this.logger.log(ctx, `${this.confirmMeal.name} was called`);

    const meal = await this.meals.confirm(ctx, fastingId, region, input);
    const saved = await this.repository.getByIdAndRegion(fastingId, region);
    return this.toOutput(saved, {
      meal,
      todayMeal: meal.revokedAt ? null : meal,
    });
  }

  /** Undoes a meal (spec 2A §4.2) and returns the person as it now is. */
  async revokeMeal(
    ctx: RequestContext,
    eventId: string,
  ): Promise<FastingOutput> {
    this.logger.log(ctx, `${this.revokeMeal.name} was called`);

    const { fastingId, regionId } = await this.meals.revoke(ctx, eventId);
    const fasting = await this.repository.getByIdAndRegion(fastingId, regionId);
    const todayMeal = await this.meals.todayMealOf(fastingId);
    return this.toOutput(fasting, { todayMeal });
  }

  /** Meals served with no network (spec 2B §4.1). */
  syncOfflineMeals(
    ctx: RequestContext,
    events: SyncMealEventInput[],
  ): Promise<MealSyncResultOutput[]> {
    this.logger.log(ctx, `${this.syncOfflineMeals.name} was called`);
    return this.meals.syncOffline(ctx, events);
  }

  /**
   * Per-day statistics for a region over an inclusive date range. Days are
   * calendar days in APP_TIMEZONE; each person counts at most once per day.
   */
  async getStatistics(
    ctx: RequestContext,
    region: number,
    start?: string,
    end?: string,
  ): Promise<DailyStatistics[]> {
    this.logger.log(ctx, `${this.getStatistics.name} was called`);

    const today = localDayKey(new Date(), this.timeZone);
    const startKey = parseDayKey(start) ?? today;
    const endKey = parseDayKey(end) ?? startKey;
    if (startKey > endKey) {
      throw new BadRequestException('start must be before or equal to end');
    }

    const { fastings, count } = await this.getFastingsByRegion(
      ctx,
      region,
      Number.MAX_SAFE_INTEGER,
      0,
    );

    const buckets = new Map<string, DailyStatistics['statistics']>();
    for (const key of enumerateDayKeys(startKey, endKey)) {
      buckets.set(key, {
        totalPersons: count,
        persons: 0,
        singleMeal: 0,
        familyMeal: 0,
        totalMeals: 0,
      });
    }

    for (const person of fastings) {
      const days = new Set<string>();
      for (const taken of person.takenMeals || []) {
        const takenAt = new Date(taken);
        if (!isNaN(takenAt.getTime())) {
          days.add(localDayKey(takenAt, this.timeZone));
        }
      }
      for (const day of days) {
        const statistics = buckets.get(day);
        if (!statistics) continue;
        const single = person.singleMeal || 0;
        const family = (person.familyMeal || 0) * FAMILY_MEAL_PORTIONS;
        statistics.persons += 1;
        statistics.singleMeal += single;
        statistics.familyMeal += family;
        statistics.totalMeals += single + family;
      }
    }

    return [...buckets.entries()].map(([key, statistics]) => ({
      date: dayKeyToLabel(key),
      statistics,
    }));
  }

  async deleteFasting(
    ctx: RequestContext,
    id: number,
    region: number,
  ): Promise<void> {
    this.logger.log(ctx, `${this.deleteFasting.name} was called`);

    this.logger.log(ctx, `calling ${FastingRepository.name}.getByIdAndRegion`);
    const fasting = await this.repository.getByIdAndRegion(id, region);

    const actor: Actor = ctx.user;

    const isAllowed = this.aclService
      .forActor(actor)
      .canDoAction(Action.Delete, fasting);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    this.logger.log(ctx, `calling ${FastingRepository.name}.remove`);
    await this.repository.remove(fasting);
  }
}
