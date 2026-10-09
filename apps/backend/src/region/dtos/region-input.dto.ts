import { ApiProperty } from '@nestjs/swagger';
import {
  IsBoolean,
  IsDefined,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateRegionInput {
  @IsString()
  @IsNotEmpty()
  @ApiProperty()
  name: string;

  @IsBoolean()
  @IsDefined()
  @ApiProperty()
  active: boolean;

  @IsBoolean()
  @IsOptional()
  @ApiProperty({ required: false, description: 'Admins only (spec 2B)' })
  allowOfflineServing?: boolean;
}

export class UpdateRegionInput {
  @IsString()
  @IsNotEmpty()
  @ApiProperty()
  name: string;

  @IsBoolean()
  @IsDefined()
  @ApiProperty()
  active: boolean;

  @IsBoolean()
  @IsOptional()
  @ApiProperty({ required: false, description: 'Admins only (spec 2B)' })
  allowOfflineServing?: boolean;
}
