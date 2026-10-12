import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';

import { Region } from '../../region/entities/region.entity';
import { User } from '../../user/entities/user.entity';

@Entity('fastings')
export class Fasting {
  /** The number printed on the card: unique within a region only. */
  @PrimaryColumn()
  id: number;

  @PrimaryColumn()
  regionId: number;

  @ManyToOne(() => Region, (region) => region.fastingPeople)
  @JoinColumn([
    { name: 'regionId', referencedColumnName: 'id' },
    { name: 'regionName', referencedColumnName: 'name' },
  ])
  region: Region;

  @Column()
  firstName: string;

  @Column()
  lastName: string;

  @Column({ nullable: true, type: 'varchar' })
  phone: string;

  @Column({ nullable: true, type: 'text' })
  comment: string;

  @Column()
  familyMeal: number;

  @Column()
  singleMeal: number;

  /** Null until the person collects their first meal. */
  @Column({ name: 'lastTakenMeal', type: 'timestamp', nullable: true })
  lastTakenMeal: Date | null;

  @Column({ type: 'varchar', array: true, default: [] })
  takenMeals: string[];

  @Column({ nullable: true })
  cin: string;

  @CreateDateColumn({ name: 'createdAt' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt' })
  updatedAt: Date;

  @ManyToOne(() => User, (user) => user.fastings, {
    eager: true,
  })
  createdBy: User;
}
