import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { DataSource } from 'typeorm';

import { loadRequestUser } from '../access/load-request-user';
import { STRATEGY_JWT_REFRESH } from '../constants/strategy.constant';
import { UserRefreshTokenClaims } from '../dtos/auth-token-output.dto';

@Injectable()
export class JwtRefreshStrategy extends PassportStrategy(
  Strategy,
  STRATEGY_JWT_REFRESH,
) {
  constructor(
    configService: ConfigService,
    private readonly dataSource: DataSource,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromBodyField('refreshToken'),
      secretOrKey: configService.get<string>('jwt.publicKey'),
      algorithms: ['RS256'],
    });
  }

  /** A disabled or pending account cannot refresh either. */
  async validate(payload: { sub: number }): Promise<UserRefreshTokenClaims> {
    const user = await loadRequestUser(this.dataSource, payload.sub);
    return { id: user.id };
  }
}
