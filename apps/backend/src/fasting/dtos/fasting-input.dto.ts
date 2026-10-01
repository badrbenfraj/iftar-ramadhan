import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDateString,
  IsDefined,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';

import { Region } from '../../region/entities/region.entity';

export class CreateFastingInput {
  @IsNumber()
  @IsNotEmpty()
  @ApiProperty()
  id: number;

  @IsString()
  @IsNotEmpty()
  @ApiProperty()
  firstName: string;

  @IsString()
  @IsNotEmpty()
  @ApiProperty()
  lastName: string;

  @IsString()
  @IsOptional()
  @ApiProperty({ required: false })
  cin: string;

  @IsNumber()
  @IsNotEmpty()
  @ApiProperty()
  region: number;

  @IsString()
  @IsOptional()
  @ApiProperty()
  comment: string;

  @IsString()
  @IsOptional()
  @ApiProperty()
  phone: string;

  @IsNumber()
  @IsNotEmpty()
  @ApiProperty()
  singleMeal: number;

  @IsNumber()
  @IsNotEmpty()
  @ApiProperty()
  familyMeal: number;

  @IsDateString()
  @IsOptional()
  @ApiProperty()
  lastTakenMeal: Date;

  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => Date)
  takenMeals: Date[];

  @IsBoolean()
  @IsOptional()
  @ApiProperty()
  cameToday: boolean;
}

export class UpdateFastingInput {
  @IsString()
  @IsNotEmpty()
  @ApiProperty()
  firstName: string;

  @IsString()
  @IsNotEmpty()
  @ApiProperty()
  lastName: string;

  @IsString()
  @IsOptional()
  @ApiProperty({ required: false })
  cin: string;

  @ApiProperty()
  @IsDefined()
  region: Region;

  @IsString()
  @IsOptional()
  @ApiProperty()
  comment: string;

  @IsString()
  @IsOptional()
  @ApiProperty()
  phone: string;

  @IsNumber()
  @IsNotEmpty()
  @ApiProperty()
  singleMeal: number;

  @IsNumber()
  @IsNotEmpty()
  @ApiProperty()
  familyMeal: number;

  @IsDateString()
  @IsOptional()
  @ApiProperty()
  lastTakenMeal: Date;

  @IsOptional()
  @ValidateNested({ each: true })
  @Type(() => Date)
  takenMeals: Date[];
}

/**
 * Body of `PATCH /fastings/confirm/:region/:id`.
 * Only phone and comment may change while confirming a meal; the meal
 * history is maintained exclusively by the server. Any other property sent
 * by older clients (e.g. the full person object) is stripped by the
 * whitelist validation pipe.
 */
export class ConfirmMealInput {
  @IsString()
  @IsOptional()
  @ApiProperty({ required: false })
  phone?: string;

  @IsString()
  @IsOptional()
  @ApiProperty({ required: false })
  comment?: string;
}
