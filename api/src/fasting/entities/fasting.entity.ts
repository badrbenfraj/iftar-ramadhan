import {
  Column,
  CreateDateColumn,
  Entity,
  ManyToOne,
  PrimaryColumn,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

import { User } from '../../user/entities/user.entity';
import { Region } from '../enums/regions.enum';

@Entity('fastings')
export class Fasting {
  @PrimaryColumn()
  id: number;

  @PrimaryColumn({ type: 'enum', enum: Region })
  region: Region;

  @Column()
  firstName: string;

  @Column()
  lastName: string;

  @Column()
  familyMeal: number;

  @Column()
  singleMeal: number;

  @Column({ name: 'lastTakenMeal' })
  lastTakenMeal: Date;

  @Column({ name: 'takenMeals' })
  takenMeals: Date[];

  @CreateDateColumn({ name: 'createdAt' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt' })
  updatedAt: Date;

  @ManyToOne(() => User, (user) => user.fastings, {
    eager: true,
  })
  createdBy: User;
}
