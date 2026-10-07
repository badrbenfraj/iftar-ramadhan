import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { plainToClass } from 'class-transformer';

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
import { Fasting } from '../entities/fasting.entity';
import { FastingRepository } from '../repositories/fasting.repository';
import { FastingAclService } from './fasting-acl.service';

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
  private toOutput(fasting: Fasting): FastingOutput {
    const { createdBy, ...rest } = fasting;
    return plainToClass(FastingOutput, {
      ...rest,
      mealTakenToday: isSameLocalDay(
        fasting.lastTakenMeal ? new Date(fasting.lastTakenMeal) : null,
        new Date(),
        this.timeZone,
      ),
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
    const savedFasting = await this.repository.save(fasting);

    return this.toOutput(savedFasting);
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

    return { fastings: fastings.map((f) => this.toOutput(f)), count };
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

    return this.toOutput(fasting);
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

    const updatedFasting: Fasting = {
      ...fasting,
      ...plainToClass(Fasting, editable),
    };

    this.logger.log(ctx, `calling ${FastingRepository.name}.save`);
    const savedFasting = await this.repository.save(updatedFasting);

    return this.toOutput(savedFasting);
  }

  /**
   * Records today's meal for a person. This is the single source of truth for
   * "one meal per person per day":
   *  - the row is locked (`SELECT ... FOR UPDATE`) so concurrent confirmations
   *    for the same person are serialized;
   *  - "today" is evaluated server-side in APP_TIMEZONE;
   *  - the history is appended server-side, never taken from the client.
   * A second confirmation on the same day fails with 409 MEAL_ALREADY_TAKEN.
   */
  async confirmMeal(
    ctx: RequestContext,
    fastingId: number,
    region: number,
    input: ConfirmMealInput,
  ): Promise<FastingOutput> {
    this.logger.log(ctx, `${this.confirmMeal.name} was called`);

    if (!Number.isInteger(fastingId) || !Number.isInteger(region)) {
      throw new NotFoundException({
        message: 'Fasting ID and Region ID are required',
        code: FASTING_ERROR_CODES.PERSON_NOT_FOUND,
      });
    }

    const actor: Actor = ctx.user;

    await this.repository.manager.transaction(async (manager) => {
      const rows: Array<{ id: number; lastTakenMeal: Date | null }> =
        await manager.query(
          `SELECT "id", "lastTakenMeal" FROM "fastings"
           WHERE "id" = $1 AND "regionId" = $2
           FOR UPDATE`,
          [fastingId, region],
        );

      if (rows.length === 0) {
        throw new NotFoundException({
          message: `Fasting record with ID ${fastingId} not found in region ${region}`,
          code: FASTING_ERROR_CODES.PERSON_NOT_FOUND,
        });
      }

      const fasting = await manager.findOne(Fasting, {
        where: { id: fastingId },
      });
      const isAllowed = this.aclService
        .forActor(actor)
        .canDoAction(Action.Update, fasting);
      if (!isAllowed) {
        throw new UnauthorizedException();
      }

      const now = new Date();
      const lastTakenMeal = rows[0].lastTakenMeal
        ? new Date(rows[0].lastTakenMeal)
        : null;

      if (isSameLocalDay(lastTakenMeal, now, this.timeZone)) {
        throw new ConflictException({
          message: 'Meal already collected today',
          code: FASTING_ERROR_CODES.MEAL_ALREADY_TAKEN,
          lastTakenMeal: lastTakenMeal.toISOString(),
        });
      }

      const phone = input.phone === undefined ? null : input.phone;
      const comment = input.comment === undefined ? null : input.comment;
      const hasPhone = input.phone !== undefined;
      const hasComment = input.comment !== undefined;

      await manager.query(
        `UPDATE "fastings"
         SET "lastTakenMeal" = $3,
             "takenMeals" = array_append("takenMeals", $4::varchar),
             "phone" = CASE WHEN $5::boolean THEN $6::varchar ELSE "phone" END,
             "comment" = CASE WHEN $7::boolean THEN $8::text ELSE "comment" END,
             "updatedAt" = now()
         WHERE "id" = $1 AND "regionId" = $2`,
        [
          fastingId,
          region,
          now,
          now.toISOString(),
          hasPhone,
          phone,
          hasComment,
          comment,
        ],
      );
    });

    const saved = await this.repository.getByIdAndRegion(fastingId, region);
    return this.toOutput(saved);
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
