import {
  BadRequestException,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { DataSource } from 'typeorm';

import { canAccessRegion, regionForbidden } from '../access/access-policy';
import { AUTH_ERROR_CODES } from '../access/auth-error-codes';
import { SKIP_REGION_CHECK_KEY } from '../decorators/skip-region-check.decorator';
import { UserAccessTokenClaims } from '../dtos/auth-token-output.dto';

/**
 * Runs after JwtAuthGuard on every route with a `:region` param: the caller
 * must be a global admin or belong to that region (security spec §3.3).
 * A closed region is read-only, for global admins too: its history stays
 * as it was when it closed.
 */
@Injectable()
export class RegionAccessGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly dataSource: DataSource,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const skip = this.reflector.getAllAndOverride<boolean>(
      SKIP_REGION_CHECK_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (skip) return true;

    const request = context.switchToHttp().getRequest();
    const raw = request.params?.region;
    if (raw === undefined) return true;
    const regionId = Number(raw);
    if (!Number.isInteger(regionId) || regionId < 1) {
      throw new BadRequestException('region must be a positive integer');
    }
    const user = request.user as UserAccessTokenClaims;
    if (!user || !canAccessRegion(user, regionId)) {
      throw regionForbidden();
    }
    if (request.method !== 'GET') {
      const [region]: Array<{ active: boolean }> = await this.dataSource.query(
        `SELECT "active" FROM "regions" WHERE "id" = $1`,
        [regionId],
      );
      if (region && !region.active) {
        throw new ForbiddenException({
          message: 'This region is closed',
          code: AUTH_ERROR_CODES.REGION_CLOSED,
        });
      }
    }
    return true;
  }
}
