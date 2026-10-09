import { ApiProperty } from '@nestjs/swagger';
import { Expose, Transform, Type } from 'class-transformer';

import { ROLE } from '../../auth/constants/role.constant';
import { Region } from '../../region/entities/region.entity';
import { USER_STATUS, type UserStatus } from '../constants/user-status.constant';

/** Region summary embedded in user responses (no nested user data). */
export class UserRegionOutput {
  @Expose()
  @ApiProperty()
  id: number;

  @Expose()
  @ApiProperty()
  name: string;

  @Expose()
  @ApiProperty()
  active: boolean;

  @Expose()
  @ApiProperty({ description: 'Volunteers may serve with no network (spec 2B)' })
  allowOfflineServing: boolean;

  @Expose()
  @ApiProperty()
  createdAt: Date;

  @Expose()
  @ApiProperty()
  updatedAt: Date;
}

export class UserOutput {
  @Expose()
  @ApiProperty()
  id: number;

  @Expose()
  @ApiProperty()
  name: string;

  @Expose()
  @ApiProperty()
  username: string;

  @Expose()
  @ApiProperty()
  email: string;

  @Expose()
  @ApiProperty({ enum: ['pending', 'active', 'disabled'] })
  status: UserStatus;

  /** Kept for app versions that predate `status`. */
  @Expose()
  @Transform(({ obj }) => obj.status === USER_STATUS.DISABLED)
  @ApiProperty()
  isAccountDisabled: boolean;

  @Expose()
  @ApiProperty()
  joinedWithCode: boolean;

  @Expose()
  @ApiProperty({ example: [ROLE.USER] })
  roles: ROLE[];

  @Expose()
  @ApiProperty({ type: () => UserRegionOutput })
  @Type(() => UserRegionOutput)
  region: Region;

  @Expose()
  @ApiProperty()
  createdAt: string;

  @Expose()
  @ApiProperty()
  updatedAt: string;
}
