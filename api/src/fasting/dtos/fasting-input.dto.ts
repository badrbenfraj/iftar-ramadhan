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
import { Region } from 'src/region/entities/region.entity';

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

  @ApiProperty()
  @IsDefined()
  @ValidateNested()
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

  @ApiProperty()
  @IsDefined()
  @ValidateNested()
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
