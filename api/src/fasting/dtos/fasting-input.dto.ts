import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDate,
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Validate,
  ValidateNested,
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

  @IsString()
  @IsOptional()
  @ApiProperty()
  comment: string;

  @IsString()
  @IsNotEmpty()
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
  @ApiProperty()
  comment: string;

  @IsString()
  @IsNotEmpty()
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
