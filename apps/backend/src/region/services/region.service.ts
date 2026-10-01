import { Injectable, UnauthorizedException } from '@nestjs/common';
import { plainToClass } from 'class-transformer';

import { Action } from '../../shared/acl/action.constant';
import { Actor } from '../../shared/acl/actor.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { User } from '../../user/entities/user.entity';
import { UserService } from '../../user/services/user.service';
import { CreateRegionInput, UpdateRegionInput } from '../dtos/region-input.dto';
import { RegionOutput } from '../dtos/region-output.dto';
import { Region } from '../entities/region.entity';
import { RegionRepository } from '../repositories/region.repository';
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

    return plainToClass(RegionOutput, savedRegion);
  }

  async getRegions(
    ctx: RequestContext,
    limit: number,
    offset: number,
  ): Promise<{ regions: RegionOutput[]; count: number }> {
    this.logger.log(ctx, `${this.getRegions.name} was called`);

    this.logger.log(ctx, `calling ${RegionRepository.name}.findAndCount`);
    const [regions, count] = await this.repository.findAndCount({
      where: { active: true },
      take: limit,
      skip: offset,
    });

    const regionsOutput = plainToClass(RegionOutput, regions);

    return { regions: regionsOutput, count };
  }

  async getRegionById(ctx: RequestContext, id: number): Promise<RegionOutput> {
    this.logger.log(ctx, `${this.getRegionById.name} was called`);

    this.logger.log(ctx, `calling ${RegionRepository.name}.getRegionById`);
    const region = await this.repository.getRegionById(id);

    return plainToClass(RegionOutput, region);
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

    const updatedRegion: Region = {
      ...region,
      ...plainToClass(Region, input),
    };

    this.logger.log(ctx, `calling ${RegionRepository.name}.save`);
    const savedRegion = await this.repository.save(updatedRegion);

    return plainToClass(RegionOutput, savedRegion);
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
}
