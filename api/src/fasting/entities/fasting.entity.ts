import {
  Column,
  CreateDateColumn,
  Entity,
  ManyToOne,
  PrimaryColumn,
  UpdateDateColumn,
} from 'typeorm';

import { Region } from '../../region/entities/region.entity';
import { User } from '../../user/entities/user.entity';

@Entity('fastings')
export class Fasting {
  @PrimaryColumn()
  id: number;

  @ManyToOne(() => Region, (region) => region.fastingPeople)
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

  @Column({ name: 'lastTakenMeal' })
  lastTakenMeal: Date;

  @Column({ type: 'varchar', array: true, default: [] })
  takenMeals: string[];

  @CreateDateColumn({ name: 'createdAt' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt' })
  updatedAt: Date;

  @ManyToOne(() => User, (user) => user.fastings, {
    eager: true,
  })
  createdBy: User;
}
