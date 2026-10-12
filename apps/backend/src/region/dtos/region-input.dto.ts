import { ApiProperty } from '@nestjs/swagger';
import {
  IsBoolean,
  IsDefined,
  IsInt,
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

/** Only the fields sent change. Closing and reopening have their own routes. */
export class UpdateRegionInput {
  @IsString()
  @IsNotEmpty()
  @IsOptional()
  @ApiProperty({ required: false })
  name?: string;

  @IsBoolean()
  @IsOptional()
  @ApiProperty({ required: false, description: 'Admins only (spec 2B)' })
  allowOfflineServing?: boolean;
}

export class CloseRegionInput {
  @IsInt()
  @IsOptional()
  @ApiProperty({
    required: false,
    description: 'Move its volunteers and coordinators to this open region',
  })
  moveUsersTo?: number;
}
