import {
  BadRequestException,
  ConflictException,
  HttpStatus,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { plainToClass } from 'class-transformer';

import { Region } from '../../region/entities/region.entity';
import { RegionRepository } from '../../region/repositories/region.repository';
import { normalizeJoinCode } from '../../region/services/join-code';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { USER_STATUS } from '../../user/constants/user-status.constant';
import { CreateUserInput } from '../../user/dtos/user-create-input.dto';
import { UserOutput } from '../../user/dtos/user-output.dto';
import { UserService } from '../../user/services/user.service';
import { AUTH_ERROR_CODES } from '../access/auth-error-codes';
import { ROLE } from '../constants/role.constant';
import { NewAccount, RegisterInput } from '../dtos/auth-register-input.dto';
import { RegisterOutput } from '../dtos/auth-register-output.dto';
import {
  AuthTokenOutput,
  UserAccessTokenClaims,
} from '../dtos/auth-token-output.dto';

@Injectable()
export class AuthService {
  constructor(
    private userService: UserService,
    private jwtService: JwtService,
    private configService: ConfigService,
    private readonly logger: AppLogger,
    private readonly regionRepository: RegionRepository,
  ) {
    this.logger.setContext(AuthService.name);
  }

  async validateUser(
    ctx: RequestContext,
    username: string,
    pass: string,
  ): Promise<UserAccessTokenClaims> {
    this.logger.log(ctx, `${this.validateUser.name} was called`);

    // The userService will throw Unauthorized in case of invalid username/password.
    const user = await this.userService.validateUsernamePassword(
      ctx,
      username,
      pass,
    );

    // Prevent disabled users from logging in.
    if (user.status === USER_STATUS.PENDING) {
      throw new UnauthorizedException({
        message: 'This account is waiting for approval',
        code: AUTH_ERROR_CODES.ACCOUNT_PENDING,
      });
    }
    if (user.status !== USER_STATUS.ACTIVE) {
      throw new UnauthorizedException({
        message: 'This user account has been disabled',
        code: AUTH_ERROR_CODES.ACCOUNT_DISABLED,
      });
    }

    return {
      id: user.id,
      username: user.username,
      roles: user.roles,
      regionId: user.region?.id ?? null,
    };
  }

  login(ctx: RequestContext): AuthTokenOutput {
    this.logger.log(ctx, `${this.login.name} was called`);

    return this.getAuthToken(ctx, ctx.user);
  }

  async register(
    ctx: RequestContext,
    input: RegisterInput,
  ): Promise<RegisterOutput> {
    this.logger.log(ctx, `${this.register.name} was called`);

    let region: Region | null;
    let joinedWithCode = false;
    const code = input.joinCode?.trim();
    if (code) {
      region = await this.regionRepository.findActiveByJoinCode(
        normalizeJoinCode(code),
      );
      if (!region) {
        throw new BadRequestException({
          message: 'This join code is not valid',
          code: AUTH_ERROR_CODES.INVALID_JOIN_CODE,
        });
      }
      joinedWithCode = true;
    } else {
      region = await this.regionRepository.findOne({
        where: { id: input.region.id, active: true },
      });
      if (!region) {
        throw new NotFoundException('Region not found');
      }
    }

    const account: NewAccount = {
      name: input.name,
      username: input.username,
      password: input.password,
      email: input.email,
      roles: [ROLE.USER],
      status: joinedWithCode ? USER_STATUS.ACTIVE : USER_STATUS.PENDING,
      joinedWithCode,
      region,
    };
    try {
      const registeredUser = await this.userService.createUser(
        ctx,
        account as unknown as CreateUserInput,
      );
      return plainToClass(RegisterOutput, registeredUser, {
        excludeExtraneousValues: true,
      });
    } catch (error) {
      if (error.status === HttpStatus.CONFLICT) {
        throw new ConflictException('Username or email is already in use');
      }
      throw error;
    }
  }

  async refreshToken(ctx: RequestContext): Promise<AuthTokenOutput> {
    this.logger.log(ctx, `${this.refreshToken.name} was called`);

    const user = await this.userService.findById(ctx, ctx.user.id);
    if (!user) {
      throw new UnauthorizedException('Invalid user id');
    }

    return this.getAuthToken(ctx, user);
  }

  getAuthToken(
    ctx: RequestContext,
    user: UserAccessTokenClaims | UserOutput,
  ): AuthTokenOutput {
    this.logger.log(ctx, `${this.getAuthToken.name} was called`);

    const subject = { sub: user.id };
    const payload = {
      username: user.username,
      sub: user.id,
      roles: user.roles,
    };

    const authToken = {
      refreshToken: this.jwtService.sign(subject, {
        expiresIn: this.configService.get('jwt.refreshTokenExpiresInSec'),
      }),
      accessToken: this.jwtService.sign(
        { ...payload, ...subject },
        { expiresIn: this.configService.get('jwt.accessTokenExpiresInSec') },
      ),
    };
    return plainToClass(AuthTokenOutput, authToken);
  }
}
