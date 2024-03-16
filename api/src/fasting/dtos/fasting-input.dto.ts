import { ApiProperty } from '@nestjs/swagger';
import {
  IsDateString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
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
}
