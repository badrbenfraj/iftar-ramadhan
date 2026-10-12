import {
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { Observable } from 'rxjs';

import { AUTH_ERROR_CODES } from '../access/auth-error-codes';
import { STRATEGY_JWT_AUTH } from '../constants/strategy.constant';
import { ALLOW_CLOSED_REGION_KEY } from '../decorators/allow-closed-region.decorator';
import { UserAccessTokenClaims } from '../dtos/auth-token-output.dto';

@Injectable()
export class JwtAuthGuard extends AuthGuard(STRATEGY_JWT_AUTH) {
  constructor(private readonly reflector: Reflector) {
    super();
  }

  canActivate(
    context: ExecutionContext,
  ): boolean | Promise<boolean> | Observable<boolean> {
    return super.canActivate(context);
  }

  handleRequest<TUser = UserAccessTokenClaims>(
    err: unknown,
    user: TUser | false,
    info: unknown,
    context: ExecutionContext,
  ): TUser {
    if (err || !user) {
      throw err || new UnauthorizedException(`${info}`);
    }
    // A closed region blocks its volunteers and coordinators everywhere
    // except the routes they need to see why and to sync offline meals.
    const claims = user as unknown as UserAccessTokenClaims;
    if (
      claims.regionClosed &&
      !this.reflector.getAllAndOverride<boolean>(ALLOW_CLOSED_REGION_KEY, [
        context.getHandler(),
        context.getClass(),
      ])
    ) {
      throw new ForbiddenException({
        message: 'Your region was closed',
        code: AUTH_ERROR_CODES.REGION_CLOSED,
      });
    }
    return user;
  }
}
