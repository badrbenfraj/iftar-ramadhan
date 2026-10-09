import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  IsDefined,
  IsEmail,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  MaxLength,
  Min,
  ValidateIf,
  ValidateNested,
} from 'class-validator';

import { Region } from '../../region/entities/region.entity';
import { type UserStatus } from '../../user/constants/user-status.constant';
import { ROLE } from '../constants/role.constant';

export class RegisterRegionInput {
  @IsInt()
  @Min(1)
  @ApiProperty()
  id: number;
}

/**
 * Security spec §4.1: a join code gives instant access to its region;
 * without one, `region` is required and the account waits for approval.
 */
export class RegisterInput {
  @ApiProperty()
  @IsNotEmpty()
  @MaxLength(100)
  @IsString()
  name: string;

  @ApiProperty()
  @IsNotEmpty()
  @MaxLength(200)
  @IsString()
  username: string;

  @ApiPropertyOptional({ example: 'NOUR-482193' })
  @IsOptional()
  @IsString()
  @MaxLength(32)
  joinCode?: string;

  @ApiPropertyOptional({ type: () => RegisterRegionInput })
  @ValidateIf((o: RegisterInput) => !o.joinCode?.trim())
  @IsDefined()
  @ValidateNested()
  @Type(() => RegisterRegionInput)
  region?: RegisterRegionInput;

  @ApiProperty()
  @IsNotEmpty()
  @Length(8, 100)
  @IsString()
  password: string;

  @ApiProperty()
  @IsNotEmpty()
  @IsEmail()
  @MaxLength(100)
  email: string;
}

/** What the service hands to UserService.createUser. */
export interface NewAccount {
  name: string;
  username: string;
  password: string;
  email: string;
  roles: ROLE[];
  status: UserStatus;
  joinedWithCode: boolean;
  region: Region;
}
