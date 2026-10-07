import {
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DataSource, EntityManager } from 'typeorm';

import { Action } from '../../shared/acl/action.constant';
import { Actor } from '../../shared/acl/actor.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import {
  DEFAULT_APP_TIMEZONE,
  isSameLocalDay,
  localDayKey,
} from '../../shared/utils/local-day';
import { FASTING_ERROR_CODES } from '../constants/error-codes';
import { ConfirmMealInput } from '../dtos/fasting-input.dto';
import { MealEventOutput } from '../dtos/meal-event-output.dto';
import { Fasting } from '../entities/fasting.entity';
import { FastingAclService } from './fasting-acl.service';

/** A meal event row joined with the serving volunteer's name. */
export interface MealEventRow {
  eventId: string;
  fastingId: number;
  regionId: number;
  servedAt: Date;
  receivedAt: Date;
  /** YYYY-MM-DD (selected as text: the pg driver would turn a date into a local-midnight Date). */
  serviceDay: string;
  servedByUserId: number | null;
  servedByName: string | null;
  conflict: boolean;
  revokedAt: Date | null;
}

const EVENT_SELECT = `SELECT e."id" AS "eventId", e."fastingId", e."regionId",
  e."servedAt", e."receivedAt", e."serviceDay"::text AS "serviceDay",
  e."servedByUserId", u."name" AS "servedByName", e."conflict", e."revokedAt"
  FROM "meal_events" e LEFT JOIN "users" u ON u."id" = e."servedByUserId"`;

export function toMealEventOutput(row: MealEventRow): MealEventOutput {
  return {
    eventId: row.eventId,
    servedAt: new Date(row.servedAt).toISOString(),
    servedBy:
      row.servedByUserId == null
        ? null
        : { id: row.servedByUserId, name: row.servedByName ?? '' },
    revokedAt: row.revokedAt ? new Date(row.revokedAt).toISOString() : null,
  };
}

/**
 * Meals handed over (spec 2A). `meal_events` is the record; every insert or
 * revoke of an active event is mirrored into `fastings.takenMeals` /
 * `lastTakenMeal` in the same transaction (dual-write, §3.3). The
 * `SELECT … FOR UPDATE` on the person's `fastings` row serializes all writes
 * for that person.
 */
@Injectable()
export class MealEventService {
  constructor(
    private readonly dataSource: DataSource,
    private readonly aclService: FastingAclService,
    private readonly configService: ConfigService,
    private readonly logger: AppLogger,
  ) {
    this.logger.setContext(MealEventService.name);
  }

  private get timeZone(): string {
    return this.configService.get<string>('timezone') || DEFAULT_APP_TIMEZONE;
  }

  /** The distribution day (APP_TIMEZONE) an instant belongs to. */
  serviceDay(at: Date): string {
    return localDayKey(at, this.timeZone);
  }

  /**
   * Records tonight's meal. With a `clientEventId` already stored for this
   * person, returns that meal instead (a retry). A second meal the same day
   * fails with 409 MEAL_ALREADY_TAKEN, saying when and by whom.
   */
  async confirm(
    ctx: RequestContext,
    fastingId: number,
    region: number,
    input: ConfirmMealInput,
  ): Promise<MealEventOutput> {
    this.logger.log(ctx, `${this.confirm.name} was called`);

    if (!Number.isInteger(fastingId) || !Number.isInteger(region)) {
      throw new NotFoundException({
        message: 'Fasting ID and Region ID are required',
        code: FASTING_ERROR_CODES.PERSON_NOT_FOUND,
      });
    }

    const actor: Actor = ctx.user;

    return this.dataSource.transaction(async (manager) => {
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

      if (input.clientEventId) {
        const existing = await this.findEvent(manager, input.clientEventId);
        if (existing) {
          if (existing.fastingId !== fastingId) {
            throw new UnprocessableEntityException({
              message: 'This clientEventId was already used for another person',
              code: FASTING_ERROR_CODES.CLIENT_EVENT_ID_REUSED,
            });
          }
          return toMealEventOutput(existing);
        }
      }

      const now = new Date();
      const active = await this.activeEventOn(
        manager,
        fastingId,
        this.serviceDay(now),
      );
      const lastTakenMeal = rows[0].lastTakenMeal
        ? new Date(rows[0].lastTakenMeal)
        : null;
      // The event is the record. The lastTakenMeal check is a safety net for
      // a meal written without an event (none should exist after the backfill).
      if (active || isSameLocalDay(lastTakenMeal, now, this.timeZone)) {
        const meal = active ? toMealEventOutput(active) : null;
        const servedAt = meal?.servedAt ?? lastTakenMeal.toISOString();
        throw new ConflictException({
          message: 'Meal already collected today',
          code: FASTING_ERROR_CODES.MEAL_ALREADY_TAKEN,
          // Read by older apps.
          lastTakenMeal: servedAt,
          servedAt,
          servedBy: meal?.servedBy ?? null,
        });
      }

      const eventId = await this.insertActive(manager, {
        id: input.clientEventId ?? null,
        fastingId,
        regionId: region,
        servedAt: now,
        servedByUserId: actor.id,
        deviceId: input.deviceId ?? null,
      });

      const phone = input.phone === undefined ? null : input.phone;
      const comment = input.comment === undefined ? null : input.comment;
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
          input.phone !== undefined,
          phone,
          input.comment !== undefined,
          comment,
        ],
      );

      return toMealEventOutput(await this.findEvent(manager, eventId));
    });
  }

  /** Inserts an active online event and returns its ID. Does not dual-write. */
  async insertActive(
    manager: EntityManager,
    event: {
      id: string | null;
      fastingId: number;
      regionId: number;
      servedAt: Date;
      servedByUserId: number;
      deviceId: string | null;
    },
  ): Promise<string> {
    const [row] = await manager.query(
      `INSERT INTO "meal_events"
         ("id","fastingId","regionId","servedAt","serviceDay","servedByUserId","source","deviceId")
       VALUES (COALESCE($1::uuid, gen_random_uuid()), $2, $3, $4, $5, $6, 'online', $7)
       RETURNING "id"`,
      [
        event.id,
        event.fastingId,
        event.regionId,
        event.servedAt,
        this.serviceDay(event.servedAt),
        event.servedByUserId,
        event.deviceId,
      ],
    );
    return row.id;
  }

  async findEvent(
    manager: EntityManager,
    id: string,
  ): Promise<MealEventRow | null> {
    const rows = await manager.query(`${EVENT_SELECT} WHERE e."id" = $1`, [id]);
    return rows[0] ?? null;
  }

  async activeEventOn(
    manager: EntityManager,
    fastingId: number,
    serviceDay: string,
  ): Promise<MealEventRow | null> {
    const rows = await manager.query(
      `${EVENT_SELECT}
       WHERE e."fastingId" = $1 AND e."serviceDay" = $2
         AND e."revokedAt" IS NULL AND e."conflict" = false`,
      [fastingId, serviceDay],
    );
    return rows[0] ?? null;
  }

  /** Tonight's active meal per person of a region (one query for a list). */
  async todayMealsByRegion(
    regionId: number,
    now: Date = new Date(),
  ): Promise<Map<number, MealEventOutput>> {
    const rows: MealEventRow[] = await this.dataSource.query(
      `${EVENT_SELECT}
       WHERE e."regionId" = $1 AND e."serviceDay" = $2
         AND e."revokedAt" IS NULL AND e."conflict" = false`,
      [regionId, this.serviceDay(now)],
    );
    return new Map(rows.map((row) => [row.fastingId, toMealEventOutput(row)]));
  }

  async todayMealOf(
    fastingId: number,
    now: Date = new Date(),
  ): Promise<MealEventOutput | null> {
    const row = await this.activeEventOn(
      this.dataSource.manager,
      fastingId,
      this.serviceDay(now),
    );
    return row ? toMealEventOutput(row) : null;
  }

  /** Every meal of a person, newest first, undone ones included. */
  async mealsOf(fastingId: number): Promise<MealEventOutput[]> {
    const rows: MealEventRow[] = await this.dataSource.query(
      `${EVENT_SELECT}
       WHERE e."fastingId" = $1 AND e."conflict" = false
       ORDER BY e."servedAt" DESC`,
      [fastingId],
    );
    return rows.map(toMealEventOutput);
  }

  /**
   * "Came today" at registration is a real meal: it blocks a second one and
   * can be undone like any other. The caller has already written
   * takenMeals / lastTakenMeal.
   */
  recordRegistrationMeal(
    manager: EntityManager,
    meal: {
      fastingId: number;
      regionId: number;
      servedAt: Date;
      servedByUserId: number;
    },
  ): Promise<string> {
    return this.insertActive(manager, { ...meal, id: null, deviceId: null });
  }
}
