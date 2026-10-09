import {
  Column,
  CreateDateColumn,
  Entity,
  ManyToOne,
  OneToMany,
  PrimaryGeneratedColumn,
  Unique,
  UpdateDateColumn,
} from 'typeorm';

import { Fasting } from '../../fasting/entities/fasting.entity';
import { Region } from '../../region/entities/region.entity';
import { USER_STATUS, type UserStatus } from '../constants/user-status.constant';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => Region, (region) => region.users, { nullable: true })
  region?: Region;

  @Column({ length: 100 })
  name: string;

  @Column()
  password: string;

  @Unique('username', ['username'])
  @Column({ length: 200 })
  username: string;

  @Column('simple-array')
  roles: string[];

  @Column({ length: 16, default: USER_STATUS.ACTIVE })
  status: UserStatus;

  /** Who approved a pending account (null for code joins and old accounts). */
  @Column({ type: 'int', nullable: true })
  approvedByUserId: number | null;

  @Column({ type: 'timestamptz', nullable: true })
  approvedAt: Date | null;

  @Column({ default: false })
  joinedWithCode: boolean;

  @Unique('email', ['email'])
  @Column({ length: 200 })
  email: string;

  @CreateDateColumn({ name: 'createdAt', nullable: true })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt', nullable: true })
  updatedAt: Date;

  @OneToMany(() => Fasting, (fasting) => fasting.createdBy)
  fastings: Fasting[];
}
