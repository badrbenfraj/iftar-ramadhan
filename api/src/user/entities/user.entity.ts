import { Region } from 'src/region/entities/region.entity';
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

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @ManyToOne(() => Region, (region) => region.users)
  region: Region;

  @Column({ length: 100 })
  name: string;

  @Column()
  password: string;

  @Unique('username', ['username'])
  @Column({ length: 200 })
  username: string;

  @Column('simple-array')
  roles: string[];

  @Column()
  isAccountDisabled: boolean;

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
