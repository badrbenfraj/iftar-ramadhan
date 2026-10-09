import { ApiProperty } from '@nestjs/swagger';
import { Expose } from 'class-transformer';

import { ROLE } from '../constants/role.constant';

export class AuthTokenOutput {
  @Expose()
  @ApiProperty({ type: () => String, description: 'JWT access token' })
  accessToken: string;

  @Expose()
  @ApiProperty({ type: () => String, description: 'JWT refresh token' })
  refreshToken: string;
}

export class UserAccessTokenClaims {
  @Expose()
  @ApiProperty({ type: () => Number })
  id: number;

  @Expose()
  @ApiProperty({ type: () => String })
  username: string;

  @Expose()
  @ApiProperty({ type: () => [String], enum: ROLE, isArray: true })
  roles: ROLE[];

  /** The user's region, read from the database on every request. */
  @Expose()
  @ApiProperty({ type: () => Number, nullable: true })
  regionId: number | null;
}

export class UserRefreshTokenClaims {
  @Expose()
  @ApiProperty({ type: () => Number })
  id: number;
}
