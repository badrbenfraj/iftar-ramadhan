import { UnauthorizedException } from '@nestjs/common';
import { DataSource } from 'typeorm';

import { USER_STATUS } from '../../user/constants/user-status.constant';
import { UserAccessTokenClaims } from '../dtos/auth-token-output.dto';
import { AUTH_ERROR_CODES } from './auth-error-codes';

/**
 * The token only says who the caller is. Role, region and status come from
 * the database on every request, so disabling or moving someone applies on
 * their next request (security spec §3.4).
 */
export async function loadRequestUser(
  dataSource: DataSource,
  userId: number,
): Promise<UserAccessTokenClaims> {
  const [row]: Array<{
    id: number;
    username: string;
    roles: string;
    status: string;
    regionId: number | null;
  }> = await dataSource.query(
    `SELECT "id", "username", "roles", "status", "regionId" FROM "users" WHERE "id" = $1`,
    [userId],
  );
  if (!row) {
    throw new UnauthorizedException('Unknown user');
  }
  if (row.status === USER_STATUS.PENDING) {
    throw new UnauthorizedException({
      message: 'This account is waiting for approval',
      code: AUTH_ERROR_CODES.ACCOUNT_PENDING,
    });
  }
  if (row.status !== USER_STATUS.ACTIVE) {
    throw new UnauthorizedException({
      message: 'This user account has been disabled',
      code: AUTH_ERROR_CODES.ACCOUNT_DISABLED,
    });
  }
  return {
    id: row.id,
    username: row.username,
    // simple-array is stored comma-separated.
    roles: row.roles.split(',').filter(Boolean) as UserAccessTokenClaims['roles'],
    regionId: row.regionId,
  };
}
