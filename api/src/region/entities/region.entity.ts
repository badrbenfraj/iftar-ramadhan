import { Fasting } from 'src/fasting/entities/fasting.entity';
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

import { User } from '../../user/entities/user.entity';

@Entity('regions')
export class Region {
  @PrimaryGeneratedColumn()
  id: number;

  @PrimaryColumn()
  name: string;

  @Column()
  active: boolean;

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
