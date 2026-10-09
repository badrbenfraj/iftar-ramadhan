import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnprocessableEntityException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DataSource, EntityManager } from 'typeorm';

import {
  canAccessRegion,
  isGlobalAdmin,
  isRegionAdmin,
  regionForbidden,
} from '../../auth/access/access-policy';
import { Action } from '../../shared/acl/action.constant';
import { Actor } from '../../shared/acl/actor.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import {
  DEFAULT_APP_TIMEZONE,
  isSameLocalDay,
  localDayKey,
} from '../../shared/utils/local-day';
import { FASTING_ERROR_CODES, OFFLINE_FLAGS } from '../constants/error-codes';
import { ConfirmMealInput } from '../dtos/fasting-input.dto';
import { MealEventOutput } from '../dtos/meal-event-output.dto';
import { MealReviewItemOutput } from '../dtos/meal-review-output.dto';
import {
  MealSyncResultOutput,
  SyncMealEventInput,
} from '../dtos/meal-sync.dto';
import { Fasting } from '../entities/fasting.entity';
import { FastingAclService } from './fasting-acl.service';
import { decideRevoke } from './revoke-rules';

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

/** Offline meals older than this, or this far in the future, mean a wrong phone clock (spec 2B §4.1). */
const SYNC_PAST_LIMIT_MS = 36 * 60 * 60 * 1000;
const SYNC_FUTURE_LIMIT_MS = 5 * 60 * 1000;

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
        relations: { region: true },
      });
      const isAllowed = this.aclService
        .forActor(actor)
        .canDoAction(Action.Update, fasting);
      if (!isAllowed) {
        throw regionForbidden();
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

  /** Inserts a meal event and returns its ID. Does not dual-write. */
  async insertEvent(
    manager: EntityManager,
    event: {
      id: string | null;
      fastingId: number;
      regionId: number;
      servedAt: Date;
      servedByUserId: number;
      deviceId: string | null;
      source: 'online' | 'offline';
      conflict: boolean;
      flag: string | null;
    },
  ): Promise<string> {
    const [row] = await manager.query(
      `INSERT INTO "meal_events"
         ("id","fastingId","regionId","servedAt","serviceDay","servedByUserId","source","deviceId","conflict","flag")
       VALUES (COALESCE($1::uuid, gen_random_uuid()), $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING "id"`,
      [
        event.id,
        event.fastingId,
        event.regionId,
        event.servedAt,
        this.serviceDay(event.servedAt),
        event.servedByUserId,
        event.source,
        event.deviceId,
        event.conflict,
        event.flag,
      ],
    );
    return row.id;
  }

  /** Inserts an active online event and returns its ID. Does not dual-write. */
  insertActive(
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
    return this.insertEvent(manager, {
      ...event,
      source: 'online',
      conflict: false,
      flag: null,
    });
  }

  /**
   * Applies meals served with no network (spec 2B §4.1). Events are handled
   * in request order, each in its own transaction, and each gets a result.
   * Idempotent by clientEventId: a retried batch records nothing twice.
   */
  async syncOffline(
    ctx: RequestContext,
    events: SyncMealEventInput[],
  ): Promise<MealSyncResultOutput[]> {
    this.logger.log(
      ctx,
      `${this.syncOffline.name} was called with ${events.length} events`,
    );
    const actor: Actor = ctx.user;
    const isAdmin = isGlobalAdmin(actor);
    const actorRegionId = actor.regionId ?? null;
    const results: MealSyncResultOutput[] = [];
    for (const event of events) {
      results.push(await this.syncOne(event, actor, isAdmin, actorRegionId));
    }
    return results;
  }

  private async syncOne(
    event: SyncMealEventInput,
    actor: Actor,
    isAdmin: boolean,
    actorRegionId: number | null,
  ): Promise<MealSyncResultOutput> {
    const base = { clientEventId: event.clientEventId };

    // Idempotency first: a retry of a meal the server already has gets its
    // original answer, whatever the clock, region or person say by now.
    const stored = await this.findEvent(
      this.dataSource.manager,
      event.clientEventId,
    );
    if (stored) {
      if (stored.fastingId !== event.fastingId) {
        return {
          ...base,
          status: 'rejected',
          code: FASTING_ERROR_CODES.CLIENT_EVENT_ID_REUSED,
        };
      }
      if (!stored.conflict) return { ...base, status: 'duplicate' };
      const other = await this.activeEventOn(
        this.dataSource.manager,
        stored.fastingId,
        stored.serviceDay,
      );
      const out = other ? toMealEventOutput(other) : null;
      return {
        ...base,
        status: 'conflict',
        other: {
          servedAt: out?.servedAt ?? new Date(stored.servedAt).toISOString(),
          servedBy: out?.servedBy ?? null,
        },
      };
    }

    const servedAt = new Date(event.servedAt);
    const now = Date.now();
    if (
      isNaN(servedAt.getTime()) ||
      servedAt.getTime() > now + SYNC_FUTURE_LIMIT_MS ||
      servedAt.getTime() < now - SYNC_PAST_LIMIT_MS
    ) {
      return {
        ...base,
        status: 'rejected',
        code: FASTING_ERROR_CODES.CLOCK_OUT_OF_RANGE,
      };
    }
    if (!isAdmin && actorRegionId !== event.regionId) {
      return {
        ...base,
        status: 'rejected',
        code: FASTING_ERROR_CODES.REGION_NOT_ALLOWED,
      };
    }

    return this.dataSource.transaction(
      async (manager): Promise<MealSyncResultOutput> => {
        const rows: Array<{ id: number; lastTakenMeal: Date | null }> =
          await manager.query(
            `SELECT "id", "lastTakenMeal" FROM "fastings"
           WHERE "id" = $1 AND "regionId" = $2
           FOR UPDATE`,
            [event.fastingId, event.regionId],
          );
        if (rows.length === 0) {
          return {
            ...base,
            status: 'rejected',
            code: FASTING_ERROR_CODES.PERSON_NOT_FOUND,
          };
        }

        const serviceDay = this.serviceDay(servedAt);
        const active = await this.activeEventOn(
          manager,
          event.fastingId,
          serviceDay,
        );
        const otherOf = (lastTakenMeal: Date | null) => ({
          servedAt: active
            ? toMealEventOutput(active).servedAt
            : (lastTakenMeal?.toISOString() ?? servedAt.toISOString()),
          servedBy: active ? toMealEventOutput(active).servedBy : null,
        });
        const lastTakenMeal = rows[0].lastTakenMeal
          ? new Date(rows[0].lastTakenMeal)
          : null;

        const existing = await this.findEvent(manager, event.clientEventId);
        if (existing) {
          if (existing.fastingId !== event.fastingId) {
            return {
              ...base,
              status: 'rejected',
              code: FASTING_ERROR_CODES.CLIENT_EVENT_ID_REUSED,
            };
          }
          // A retried conflict stays visible as a conflict on the phone.
          return existing.conflict
            ? { ...base, status: 'conflict', other: otherOf(lastTakenMeal) }
            : { ...base, status: 'duplicate' };
        }

        const servedThatDay =
          active ||
          (lastTakenMeal != null &&
            localDayKey(lastTakenMeal, this.timeZone) === serviceDay);
        const insert = {
          id: event.clientEventId,
          fastingId: event.fastingId,
          regionId: event.regionId,
          servedAt,
          servedByUserId: actor.id,
          deviceId: event.deviceId ?? null,
          source: 'offline' as const,
        };

        if (servedThatDay) {
          // A second physical hand-over: recorded, never dual-written.
          await this.insertEvent(manager, {
            ...insert,
            conflict: true,
            flag: null,
          });
          return { ...base, status: 'conflict', other: otherOf(lastTakenMeal) };
        }

        const [region]: Array<{ allowOfflineServing: boolean }> =
          await manager.query(
            `SELECT "allowOfflineServing" FROM "regions" WHERE "id" = $1`,
            [event.regionId],
          );
        const flag = region?.allowOfflineServing
          ? null
          : OFFLINE_FLAGS.OFFLINE_NOT_ALLOWED;
        await this.insertEvent(manager, { ...insert, conflict: false, flag });
        // Dual-write. An offline meal may be older than the latest one, so
        // lastTakenMeal only moves forward.
        await manager.query(
          `UPDATE "fastings"
         SET "takenMeals" = array_append("takenMeals", $2::varchar),
             "lastTakenMeal" = CASE
               WHEN "lastTakenMeal" IS NULL OR "lastTakenMeal" < $3 THEN $3
               ELSE "lastTakenMeal" END,
             "updatedAt" = now()
         WHERE "id" = $1`,
          [event.fastingId, servedAt.toISOString(), servedAt],
        );
        return { ...base, status: 'applied', flag };
      },
    );
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

  /** A region's meals needing admin attention on [day] (spec 2B §4.2). */
  async reviewItems(
    regionId: number,
    day: string,
  ): Promise<MealReviewItemOutput[]> {
    const rows: Array<{
      eventId: string;
      fastingId: number;
      firstName: string;
      lastName: string;
      servedAt: Date;
      servedByUserId: number | null;
      servedByName: string | null;
      source: string;
      conflict: boolean;
      flag: string | null;
      revokedAt: Date | null;
    }> = await this.dataSource.query(
      `SELECT e."id" AS "eventId", e."fastingId", f."firstName", f."lastName",
              e."servedAt", e."servedByUserId", u."name" AS "servedByName",
              e."source", e."conflict", e."flag", e."revokedAt"
       FROM "meal_events" e
       JOIN "fastings" f ON f."id" = e."fastingId"
       LEFT JOIN "users" u ON u."id" = e."servedByUserId"
       WHERE e."regionId" = $1 AND e."serviceDay" = $2
         AND (e."conflict" = true OR e."flag" IS NOT NULL)
       ORDER BY e."fastingId", e."servedAt"`,
      [regionId, day],
    );
    return rows.map((r) => ({
      eventId: r.eventId,
      fastingId: r.fastingId,
      personName: `${r.firstName} ${r.lastName}`.trim(),
      servedAt: new Date(r.servedAt).toISOString(),
      servedBy:
        r.servedByUserId == null
          ? null
          : { id: r.servedByUserId, name: r.servedByName ?? '' },
      source: r.source,
      conflict: r.conflict,
      flag: r.flag,
      revokedAt: r.revokedAt ? new Date(r.revokedAt).toISOString() : null,
    }));
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

  private get undoWindowMinutes(): number {
    const v = this.configService.get<number>('undoWindowMinutes');
    return Number.isFinite(v) && v > 0 ? v : 10;
  }

  /**
   * Undoes a meal (spec 2A §4.2). The event is kept with revokedAt /
   * revokedByUserId; the person's history loses that meal.
   */
  async revoke(
    ctx: RequestContext,
    eventId: string,
  ): Promise<{ fastingId: number; regionId: number }> {
    this.logger.log(ctx, `${this.revoke.name} was called`);
    const actor: Actor = ctx.user;

    return this.dataSource.transaction(async (manager) => {
      const found = await this.findEvent(manager, eventId);
      if (!found) {
        throw new NotFoundException({
          message: 'Meal not found',
          code: FASTING_ERROR_CODES.MEAL_EVENT_NOT_FOUND,
        });
      }
      // A meal of another region looks like no meal at all (no id probing).
      if (!canAccessRegion(actor, found.regionId)) {
        throw new NotFoundException({
          message: 'Meal not found',
          code: FASTING_ERROR_CODES.MEAL_EVENT_NOT_FOUND,
        });
      }
      // Same lock order as confirm: the person first, then the event.
      await manager.query(
        `SELECT "id" FROM "fastings" WHERE "id" = $1 FOR UPDATE`,
        [found.fastingId],
      );
      const event = await this.findEvent(manager, eventId);
      const ids = { fastingId: event.fastingId, regionId: event.regionId };

      switch (
        decideRevoke(event, actor, new Date(), {
          windowMinutes: this.undoWindowMinutes,
          timeZone: this.timeZone,
          canAdminister: isRegionAdmin(actor, event.regionId),
        })
      ) {
        case 'alreadyRevoked':
          return ids;
        case 'notAllowed':
          throw new ForbiddenException({
            message: 'Only the volunteer who served this meal can undo it',
            code: FASTING_ERROR_CODES.UNDO_NOT_ALLOWED,
          });
        case 'windowExpired':
          throw new ForbiddenException({
            message: 'It is too late to undo this meal',
            code: FASTING_ERROR_CODES.UNDO_WINDOW_EXPIRED,
          });
        case 'allowed':
          break;
      }

      await manager.query(
        `UPDATE "meal_events" SET "revokedAt" = now(), "revokedByUserId" = $2 WHERE "id" = $1`,
        [eventId, actor.id],
      );
      if (!event.conflict) {
        await this.removeFromHistory(manager, event);
      }
      return ids;
    });
  }

  /** Dual-write of a revoke: drop that meal from takenMeals, recompute lastTakenMeal. */
  private async removeFromHistory(
    manager: EntityManager,
    event: MealEventRow,
  ): Promise<void> {
    const [row]: Array<{ takenMeals: string[] }> = await manager.query(
      `SELECT "takenMeals" FROM "fastings" WHERE "id" = $1`,
      [event.fastingId],
    );
    const taken = row?.takenMeals ?? [];
    // Compared as instants: entries are ISO strings, or dates written with
    // an offset by the registration path.
    const target = new Date(event.servedAt).getTime();
    const index = taken.findIndex((raw) => new Date(raw).getTime() === target);
    const remaining =
      index < 0 ? taken : [...taken.slice(0, index), ...taken.slice(index + 1)];

    const [latest]: Array<{ at: Date | null }> = await manager.query(
      `SELECT max("servedAt") AS "at" FROM "meal_events"
       WHERE "fastingId" = $1 AND "revokedAt" IS NULL AND "conflict" = false`,
      [event.fastingId],
    );
    await manager.query(
      `UPDATE "fastings"
       SET "takenMeals" = $2::varchar[], "lastTakenMeal" = $3, "updatedAt" = now()
       WHERE "id" = $1`,
      [event.fastingId, remaining, latest?.at ? new Date(latest.at) : null],
    );
  }
}
