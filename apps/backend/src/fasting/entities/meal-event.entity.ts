import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  JoinColumn,
  ManyToOne,
  PrimaryColumn,
} from 'typeorm';

import { User } from '../../user/entities/user.entity';
import { Fasting } from './fasting.entity';

export type MealEventSource = 'online' | 'offline' | 'backfill';

/**
 * One meal handed over, or the record of a second, conflicting hand-over
 * (`conflict = true`). The partial unique index is the database-level
 * guarantee of one active meal per person per day (spec 2A §3).
 * `fastings.takenMeals` / `lastTakenMeal` mirror the active events for
 * older clients and statistics (dual-write, spec 2A §3.3).
 */
@Entity('meal_events')
@Index('UQ_meal_events_active_day', ['fastingId', 'serviceDay'], {
  unique: true,
  where: '"revokedAt" IS NULL AND "conflict" = false',
})
@Index('IDX_meal_events_region_day', ['regionId', 'serviceDay'])
@Index('IDX_meal_events_fasting_served', ['fastingId', 'servedAt'])
export class MealEvent {
  /** The app's `clientEventId` when it sent one. */
  @PrimaryColumn({ type: 'uuid', default: () => 'gen_random_uuid()' })
  id: string;

  @Column()
  fastingId: number;

  @ManyToOne(() => Fasting, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'fastingId' })
  fasting?: Fasting;

  /**
   * Denormalized for region-scoped queries. No foreign key: `regions` has a
   * composite primary key (id, name).
   */
  @Column()
  regionId: number;

  /** Server time for online confirms. */
  @Column({ type: 'timestamptz' })
  servedAt: Date;

  /** Local day of `servedAt` in APP_TIMEZONE (YYYY-MM-DD). */
  @Column({ type: 'date' })
  serviceDay: string;

  @CreateDateColumn({ type: 'timestamptz' })
  receivedAt: Date;

  /** Null only for history backfilled from `fastings.takenMeals`. */
  @Column({ type: 'int', nullable: true })
  servedByUserId: number | null;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'servedByUserId' })
  servedBy?: User | null;

  @Column({ type: 'varchar', length: 16 })
  source: MealEventSource;

  @Column({ type: 'varchar', length: 64, nullable: true })
  deviceId: string | null;

  @Column({ default: false })
  conflict: boolean;

  /** Admin-review marker; unused until Spec 2B. */
  @Column({ type: 'varchar', nullable: true })
  flag: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  revokedAt: Date | null;

  @Column({ type: 'int', nullable: true })
  revokedByUserId: number | null;

  @ManyToOne(() => User, { nullable: true })
  @JoinColumn({ name: 'revokedByUserId' })
  revokedBy?: User | null;
}
