import { ApiProperty } from '@nestjs/swagger';
import {
  IsEmail,
  IsNotEmpty,
  IsString,
  Length,
  MaxLength,
} from 'class-validator';

import { Region } from '../../region/entities/region.entity';
import { type UserStatus } from '../../user/constants/user-status.constant';
import { ROLE } from '../constants/role.constant';

/**
 * The join code picks the region (regions are never listed publicly); the
 * region decides whether the account waits for approval.
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

  @ApiProperty({ example: 'NOUR-482193' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(32)
  joinCode: string;

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
  region: Region;
}
