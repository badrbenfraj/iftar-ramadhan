import { Exclude } from 'class-transformer';
import {
  Column,
  CreateDateColumn,
  Entity,
  JoinColumn,
  ManyToOne,
  OneToMany,
  PrimaryColumn,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from 'typeorm';

import { Fasting } from '../../fasting/entities/fasting.entity';
import { User } from '../../user/entities/user.entity';

@Entity('regions')
export class Region {
  @PrimaryGeneratedColumn()
  id: number;

  @PrimaryColumn()
  name: string;

  @Column()
  active: boolean;

  /** Spec 2B: volunteers may serve with no network here. On by default. */
  @Column({ default: true })
  allowOfflineServing: boolean;

  /** Shared in the volunteers' group; registering with it skips approval. Null = off. */
  @Exclude()
  @Column({ type: 'varchar', length: 32, nullable: true })
  joinCode: string | null;

  @OneToMany(() => Fasting, (fastingPerson) => fastingPerson.region)
  fastingPeople: Fasting[];

  @OneToMany(() => User, (user) => user.region)
  users: User[];

  @CreateDateColumn({ name: 'createdAt' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updatedAt' })
  updatedAt: Date;

  @ManyToOne(() => User, (user) => user, { nullable: true })
  @JoinColumn({ name: 'createdBy' })
  createdBy?: User;
}
