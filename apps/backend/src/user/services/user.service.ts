import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { compare, hash } from 'bcrypt';
import { plainToClass } from 'class-transformer';

import {
  canManageUser,
  isAnyAdmin,
  isGlobalAdmin,
  regionForbidden,
} from '../../auth/access/access-policy';
import { ROLE } from '../../auth/constants/role.constant';
import { Region } from '../../region/entities/region.entity';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { USER_STATUS, UserStatus } from '../constants/user-status.constant';
import { CreateUserInput } from '../dtos/user-create-input.dto';
import { UserOutput } from '../dtos/user-output.dto';
import { User } from '../entities/user.entity';
import { UserRepository } from '../repositories/user.repository';

@Injectable()
export class UserService {
  constructor(
    private repository: UserRepository,
    private readonly logger: AppLogger,
  ) {
    this.logger.setContext(UserService.name);
  }
  async createUser(
    ctx: RequestContext,
    input: CreateUserInput,
  ): Promise<UserOutput> {
    this.logger.log(ctx, `${this.createUser.name} was called`);

    const existingUser = await this.repository.findOne({
      where: [{ username: input.username }, { email: input.email }],
    });

    if (existingUser) {
      throw new ConflictException('Username or email is already in use');
    }

    const user = plainToClass(User, input);

    user.password = await hash(input.password, 10);

    this.logger.log(ctx, `calling ${UserRepository.name}.saveUser`);
    await this.repository.save(user);

    return plainToClass(UserOutput, user, { excludeExtraneousValues: true });
  }

  async validateUsernamePassword(
    ctx: RequestContext,
    username: string,
    pass: string,
  ): Promise<UserOutput> {
    this.logger.log(ctx, `${this.validateUsernamePassword.name} was called`);

    this.logger.log(ctx, `calling ${UserRepository.name}.findOne`);
    const user = await this.repository.findOne({
      where: { username },
      relations: { region: true },
    });
    if (!user) throw new UnauthorizedException();

    const match = await compare(pass, user.password);
    if (!match) throw new UnauthorizedException();

    return plainToClass(UserOutput, user, { excludeExtraneousValues: true });
  }

  /** Volunteers screen list (security spec §4.3). */
  async listForAdmin(
    ctx: RequestContext,
    query: {
      status?: UserStatus;
      regionId?: number;
      limit: number;
      offset: number;
    },
  ): Promise<{ users: UserOutput[]; count: number }> {
    const actor = ctx.user;
    if (!isAnyAdmin(actor)) {
      throw new ForbiddenException('Admins only');
    }
    let regionId = query.regionId;
    if (!isGlobalAdmin(actor)) {
      if (actor.regionId == null) throw regionForbidden();
      regionId = actor.regionId;
    }
    const [users, count] = await this.repository.findAndCount({
      where: {
        ...(query.status ? { status: query.status } : {}),
        ...(regionId ? { region: { id: regionId } } : {}),
      },
      relations: { region: true },
      order: { createdAt: 'DESC' },
      take: query.limit,
      skip: query.offset,
    });
    return {
      users: plainToClass(UserOutput, users, { excludeExtraneousValues: true }),
      count,
    };
  }

  private async loadManageable(ctx: RequestContext, id: number): Promise<User> {
    const target = await this.repository.findOne({
      where: { id },
      relations: { region: true },
    });
    // Someone you may not manage looks like nobody (no id probing).
    if (
      !target ||
      !canManageUser(ctx.user, {
        id: target.id,
        roles: target.roles,
        regionId: target.region?.id ?? null,
      })
    ) {
      throw new NotFoundException('User not found');
    }
    return target;
  }

  private async setStatus(
    ctx: RequestContext,
    id: number,
    from: UserStatus,
    to: UserStatus,
  ): Promise<UserOutput> {
    const target = await this.loadManageable(ctx, id);
    if (target.status !== from) {
      throw new BadRequestException(`This account is not ${from}`);
    }
    target.status = to;
    if (from === USER_STATUS.PENDING && to === USER_STATUS.ACTIVE) {
      target.approvedByUserId = ctx.user.id;
      target.approvedAt = new Date();
    }
    const saved = await this.repository.save(target);
    return plainToClass(UserOutput, saved, { excludeExtraneousValues: true });
  }

  approve(ctx: RequestContext, id: number): Promise<UserOutput> {
    return this.setStatus(ctx, id, USER_STATUS.PENDING, USER_STATUS.ACTIVE);
  }

  disable(ctx: RequestContext, id: number): Promise<UserOutput> {
    return this.setStatus(ctx, id, USER_STATUS.ACTIVE, USER_STATUS.DISABLED);
  }

  enable(ctx: RequestContext, id: number): Promise<UserOutput> {
    return this.setStatus(ctx, id, USER_STATUS.DISABLED, USER_STATUS.ACTIVE);
  }

  /** Refusing deletes the pending account, so the username is free again. */
  async refuse(ctx: RequestContext, id: number): Promise<void> {
    const target = await this.loadManageable(ctx, id);
    if (target.status !== USER_STATUS.PENDING) {
      throw new BadRequestException('Only a waiting account can be refused');
    }
    await this.repository.remove(target);
  }

  /** Global admins only: make coordinator / volunteer, or move region. */
  async changeRole(
    ctx: RequestContext,
    id: number,
    input: { role: ROLE.USER | ROLE.REGION_ADMIN; regionId: number },
  ): Promise<UserOutput> {
    if (!isGlobalAdmin(ctx.user)) {
      throw new ForbiddenException('Global admins only');
    }
    const target = await this.repository.findOne({
      where: { id },
      relations: { region: true },
    });
    if (!target) throw new NotFoundException('User not found');
    if (target.id === ctx.user.id || target.roles.includes(ROLE.ADMIN)) {
      throw new BadRequestException(
        'Global admin accounts are not changed here',
      );
    }
    const region = await this.repository.manager.findOne(Region, {
      where: { id: input.regionId },
    });
    if (!region) throw new NotFoundException('Region not found');
    target.roles = [input.role];
    target.region = region;
    const saved = await this.repository.save(target);
    return plainToClass(UserOutput, saved, { excludeExtraneousValues: true });
  }

  async findById(ctx: RequestContext, id: number): Promise<UserOutput> {
    this.logger.log(ctx, `${this.findById.name} was called`);

    this.logger.log(ctx, `calling ${UserRepository.name}.findOne`);
    const user = await this.repository.findOne({
      where: { id },
      relations: { region: true },
    });

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return plainToClass(UserOutput, user, { excludeExtraneousValues: true });
  }

  async getUserById(ctx: RequestContext, id: number): Promise<UserOutput> {
    this.logger.log(ctx, `${this.getUserById.name} was called`);

    this.logger.log(ctx, `calling ${UserRepository.name}.getById`);
    const user = await this.repository.getById(id);

    return plainToClass(UserOutput, user, { excludeExtraneousValues: true });
  }

  async findByUsername(
    ctx: RequestContext,
    username: string,
  ): Promise<UserOutput> {
    this.logger.log(ctx, `${this.findByUsername.name} was called`);

    this.logger.log(ctx, `calling ${UserRepository.name}.findOne`);
    const user = await this.repository.findOne({
      where: { username },
      relations: { region: true },
    });

    return plainToClass(UserOutput, user, { excludeExtraneousValues: true });
  }

  async updateUser(
    ctx: RequestContext,
    userId: number,
    input: Partial<CreateUserInput>,
  ): Promise<UserOutput> {
    this.logger.log(ctx, `${this.updateUser.name} was called`);

    const user = await this.repository.findOne({ where: { id: userId } });
    if (!user) {
      throw new NotFoundException('User not found');
    }

    const updated = await this.repository.save({
      ...user,
      ...input,
    });

    return plainToClass(UserOutput, updated, { excludeExtraneousValues: true });
  }
}
