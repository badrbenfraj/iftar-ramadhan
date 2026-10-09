import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { plainToClass } from 'class-transformer';

import {
  canAccessRegion,
  isRegionAdmin,
  regionForbidden,
} from '../../auth/access/access-policy';
import { ROLE } from '../../auth/constants/role.constant';
import { Action } from '../../shared/acl/action.constant';
import { Actor } from '../../shared/acl/actor.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { User } from '../../user/entities/user.entity';
import { UserService } from '../../user/services/user.service';
import { JoinCodeOutput } from '../dtos/join-code-output.dto';
import { PublicRegionOutput } from '../dtos/public-region-output.dto';
import { CreateRegionInput, UpdateRegionInput } from '../dtos/region-input.dto';
import { RegionOutput } from '../dtos/region-output.dto';
import { Region } from '../entities/region.entity';
import { RegionRepository } from '../repositories/region.repository';
import { generateJoinCode } from './join-code';
import { RegionAclService } from './region-acl.service';

@Injectable()
export class RegionService {
  constructor(
    private repository: RegionRepository,
    private userService: UserService,
    private aclService: RegionAclService,
    private readonly logger: AppLogger,
  ) {
    this.logger.setContext(RegionService.name);
  }

  async createRegion(
    ctx: RequestContext,
    input: CreateRegionInput,
  ): Promise<RegionOutput> {
    this.logger.log(ctx, `${this.createRegion.name} was called`);
    const region = plainToClass(Region, input);

    const actor: Actor = ctx.user;

    const user = await this.userService.getUserById(ctx, actor.id);

    const isAllowed = this.aclService
      .forActor(actor)
      .canDoAction(Action.Create, region);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    region.createdBy = plainToClass(User, user);

    this.logger.log(ctx, `calling ${RegionRepository.name}.save`);
    const savedRegion = await this.repository.save(region);

    return plainToClass(RegionOutput, savedRegion, {
      excludeExtraneousValues: true,
    });
  }

  async getRegions(
    ctx: RequestContext,
    limit: number,
    offset: number,
  ): Promise<{ regions: PublicRegionOutput[]; count: number }> {
    this.logger.log(ctx, `${this.getRegions.name} was called`);

    this.logger.log(ctx, `calling ${RegionRepository.name}.findAndCount`);
    const [regions, count] = await this.repository.findAndCount({
      where: { active: true },
      take: limit,
      skip: offset,
    });

    const regionsOutput = plainToClass(PublicRegionOutput, regions, {
      excludeExtraneousValues: true,
    });

    return { regions: regionsOutput, count };
  }

  async getRegionById(ctx: RequestContext, id: number): Promise<RegionOutput> {
    this.logger.log(ctx, `${this.getRegionById.name} was called`);

    this.logger.log(ctx, `calling ${RegionRepository.name}.getRegionById`);
    if (!canAccessRegion(ctx.user, id)) throw regionForbidden();
    const region = await this.repository.getRegionById(id);

    return plainToClass(RegionOutput, region, {
      excludeExtraneousValues: true,
    });
  }

  async updateRegion(
    ctx: RequestContext,
    id: number,
    input: UpdateRegionInput,
  ): Promise<RegionOutput> {
    this.logger.log(ctx, `${this.updateRegion.name} was called`);

    this.logger.log(ctx, `calling ${RegionRepository.name}.getRegionById`);
    const region = await this.repository.getRegionById(id);

    const actor: Actor = ctx.user;

    const isAllowed = this.aclService
      .forActor(actor)
      .canDoAction(Action.Update, region);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    // Offline serving trades double-serve safety for availability: an
    // admin decision (spec 2B §4.3).
    if (
      input.allowOfflineServing !== undefined &&
      input.allowOfflineServing !== region.allowOfflineServing &&
      !actor.roles.includes(ROLE.ADMIN)
    ) {
      throw new ForbiddenException('Only admins can change offline serving');
    }

    const updatedRegion: Region = {
      ...region,
      ...plainToClass(Region, input),
    };

    this.logger.log(ctx, `calling ${RegionRepository.name}.save`);
    const savedRegion = await this.repository.save(updatedRegion);

    return plainToClass(RegionOutput, savedRegion, {
      excludeExtraneousValues: true,
    });
  }

  async deleteRegion(ctx: RequestContext, id: number): Promise<void> {
    this.logger.log(ctx, `${this.deleteRegion.name} was called`);

    this.logger.log(ctx, `calling ${RegionRepository.name}.getRegionById`);
    const region = await this.repository.getRegionById(id);

    const actor: Actor = ctx.user;

    const isAllowed = this.aclService
      .forActor(actor)
      .canDoAction(Action.Delete, region);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    this.logger.log(ctx, `calling ${RegionRepository.name}.remove`);
    await this.repository.remove(region);
  }

  private async regionForAdmin(
    ctx: RequestContext,
    id: number,
  ): Promise<Region> {
    if (!isRegionAdmin(ctx.user, id)) throw regionForbidden();
    const region = await this.repository.findOne({ where: { id } });
    if (!region) throw new NotFoundException('Region not found');
    return region;
  }

  async getJoinCode(ctx: RequestContext, id: number): Promise<JoinCodeOutput> {
    const region = await this.regionForAdmin(ctx, id);
    return { joinCode: region.joinCode ?? null };
  }

  /** Replaces the code; the old one stops working at once. */
  async newJoinCode(ctx: RequestContext, id: number): Promise<JoinCodeOutput> {
    await this.regionForAdmin(ctx, id);
    for (let attempt = 0; attempt < 5; attempt++) {
      const joinCode = generateJoinCode();
      try {
        await this.repository.update({ id }, { joinCode });
        return { joinCode };
      } catch (error) {
        // 23505 = unique_violation: another region drew the same code.
        if (error?.code !== '23505') throw error;
      }
    }
    throw new ConflictException('Could not draw a unique code, try again');
  }

  async turnOffJoinCode(
    ctx: RequestContext,
    id: number,
  ): Promise<JoinCodeOutput> {
    await this.regionForAdmin(ctx, id);
    await this.repository.update({ id }, { joinCode: null });
    return { joinCode: null };
  }
}
