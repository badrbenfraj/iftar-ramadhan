import {
  BadRequestException,
  CanActivate,
  ExecutionContext,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { canAccessRegion, regionForbidden } from '../access/access-policy';
import { SKIP_REGION_CHECK_KEY } from '../decorators/skip-region-check.decorator';
import { UserAccessTokenClaims } from '../dtos/auth-token-output.dto';

/**
 * Runs after JwtAuthGuard on every route with a `:region` param: the caller
 * must be a global admin or belong to that region (security spec §3.3).
 */
@Injectable()
export class RegionAccessGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
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
    return true;
  }
}
