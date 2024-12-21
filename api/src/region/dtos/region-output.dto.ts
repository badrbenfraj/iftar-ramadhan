import { ApiProperty } from '@nestjs/swagger';
import { Expose } from 'class-transformer';
import { Fasting } from 'src/fasting/entities/fasting.entity';
import { User } from 'src/user/entities/user.entity';

export class RegionOutput {
  @Expose()
  @ApiProperty()
  id: number;

  @Expose()
  @ApiProperty()
  name: string;

  @Expose()
  @ApiProperty()
  active: boolean;

  @Expose()
  @ApiProperty()
  fastingPeople: Fasting[];

  @Expose()
  @ApiProperty()
  users: User[];

  @Expose()
  @ApiProperty()
  createdAt: Date;

  @Expose()
  @ApiProperty()
  updatedAt: Date;
}
