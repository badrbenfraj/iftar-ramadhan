import { ApiProperty } from '@nestjs/swagger';
import {
  IsBoolean,
  IsDate,
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Validate,
} from 'class-validator';

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
  @ApiProperty()
  @IsDate({ each: true }) // Validate each element of the array as a Date
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
  @ApiProperty()
  @IsDate({ each: true }) // Validate each element of the array as a Date
  takenMeals: Date[];
}
