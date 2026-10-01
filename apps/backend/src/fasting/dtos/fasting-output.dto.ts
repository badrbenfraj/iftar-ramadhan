import { ApiProperty } from '@nestjs/swagger';
import { Expose } from 'class-transformer';

import { Region } from '../../region/entities/region.entity';

export class FastingOutput {
  @Expose()
  @ApiProperty()
  id: number;

  @Expose()
  @ApiProperty()
  region: Region;

  @Expose()
  @ApiProperty()
  firstName: string;

  @Expose()
  @ApiProperty()
  lastName: string;

  @Expose()
  @ApiProperty({ required: false })
  cin?: string;

  @Expose()
  @ApiProperty()
  comment: string;

  @Expose()
  @ApiProperty()
  phone: string;

  @Expose()
  @ApiProperty()
  singleMeal: number;

  @Expose()
  @ApiProperty()
  familyMeal: number;

  @Expose()
  @ApiProperty({
    type: Date,
    nullable: true,
    description: 'Null until the first meal is collected',
  })
  lastTakenMeal: Date | null;

  @Expose()
  @ApiProperty()
  takenMeals: Date[];

  @Expose()
  @ApiProperty({
    description:
      'Whether the meal was already collected today (server timezone APP_TIMEZONE)',
  })
  mealTakenToday: boolean;

  @Expose()
  @ApiProperty()
  createdAt: Date;

  @Expose()
  @ApiProperty()
  updatedAt: Date;
}
