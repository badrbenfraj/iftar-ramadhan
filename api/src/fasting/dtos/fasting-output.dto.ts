import { ApiProperty } from '@nestjs/swagger';
import { Expose, Type } from 'class-transformer';
import { Region } from '../enums/regions.enum';

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
  @ApiProperty()
  lastTakenMeal: Date;

  @Expose()
  @ApiProperty()
  takenMeals: Date[];

  @Expose()
  @ApiProperty()
  createdAt: Date;

  @Expose()
  @ApiProperty()
  updatedAt: Date;
}
