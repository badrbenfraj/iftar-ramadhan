import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayNotEmpty,
  IsAlphanumeric,
  IsArray,
  IsBoolean,
  IsEmail,
  IsEnum,
  IsIn,
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  MaxLength,
} from 'class-validator';

import { ROLE } from '../../auth/constants/role.constant';
import { Region } from '../../region/entities/region.entity';
import { type UserStatus } from '../constants/user-status.constant';

export class CreateUserInput {
  @ApiPropertyOptional()
  @IsOptional()
  @IsNotEmpty()
  @IsString()
  name: string;

  @ApiPropertyOptional()
  @IsOptional()
  region?: Region;

  @ApiProperty()
  @IsNotEmpty()
  @Length(6, 100)
  @IsAlphanumeric()
  username: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsString()
  @Length(6, 100)
  password: string;

  @ApiProperty()
  @IsArray()
  @ArrayNotEmpty()
  @IsEnum(ROLE, { each: true })
  roles: ROLE[];

  @ApiProperty()
  @IsNotEmpty()
  @IsEmail()
  @MaxLength(100)
  email: string;

  @ApiProperty({ enum: ['pending', 'active', 'disabled'] })
  @IsIn(['pending', 'active', 'disabled'])
  status: UserStatus;

  @IsOptional()
  @IsBoolean()
  joinedWithCode?: boolean;
}
