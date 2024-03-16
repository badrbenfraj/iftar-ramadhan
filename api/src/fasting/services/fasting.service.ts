import { Injectable, UnauthorizedException } from '@nestjs/common';
import { plainToClass } from 'class-transformer';

import { Action } from '../../shared/acl/action.constant';
import { Actor } from '../../shared/acl/actor.constant';
import { AppLogger } from '../../shared/logger/logger.service';
import { RequestContext } from '../../shared/request-context/request-context.dto';
import { User } from '../../user/entities/user.entity';
import { UserService } from '../../user/services/user.service';
import {
  CreateFastingInput,
  UpdateFastingInput,
} from '../dtos/fasting-input.dto';
import { FastingOutput } from '../dtos/fasting-output.dto';
import { Fasting } from '../entities/fasting.entity';
import { FastingRepository } from '../repositories/fasting.repository';
import { FastingAclService } from './fasting-acl.service';
import { Region } from '../enums/regions.enum';

@Injectable()
export class FastingService {
  constructor(
    private repository: FastingRepository,
    private userService: UserService,
    private aclService: FastingAclService,
    private readonly logger: AppLogger,
  ) {
    this.logger.setContext(FastingService.name);
  }

  async createFasting(
    ctx: RequestContext,
    region: Region,
    input: CreateFastingInput,
  ): Promise<FastingOutput> {
    this.logger.log(ctx, `${this.createFasting.name} was called`);
    input['region'] = region;
    const fasting = plainToClass(Fasting, input);

    const actor: Actor = ctx.user;

    const user = await this.userService.getUserById(ctx, actor.id);

    const isAllowed = this.aclService
      .forActor(actor)
      .canDoAction(Action.Create, fasting);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    fasting.createdBy = plainToClass(User, user);

    this.logger.log(ctx, `calling ${FastingRepository.name}.save`);
    const savedFasting = await this.repository.save(fasting);

    return plainToClass(FastingOutput, savedFasting, {
      excludeExtraneousValues: true,
    });
  }

  async getFastingsByRegion(
    ctx: RequestContext,
    region: Region,
    limit: number,
    offset: number,
  ): Promise<{ fastings: FastingOutput[]; count: number }> {
    this.logger.log(ctx, `${this.getFastings.name} was called`);

    const actor: Actor = ctx.user;

    const isAllowed = this.aclService.forActor(actor).canDoAction(Action.List);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    this.logger.log(ctx, `calling ${FastingRepository.name}.findAndCount`);
    const [fastings, count] = await this.repository.findAndCount({
      where: {
        region,
      },
      take: limit,
      skip: offset,
    });

    const fastingsOutput = plainToClass(FastingOutput, fastings, {
      excludeExtraneousValues: true,
    });

    return { fastings: fastingsOutput, count };
  }

  async getFastings(
    ctx: RequestContext,
    limit: number,
    offset: number,
  ): Promise<{ fastings: FastingOutput[]; count: number }> {
    this.logger.log(ctx, `${this.getFastings.name} was called`);

    const actor: Actor = ctx.user;

    const isAllowed = this.aclService.forActor(actor).canDoAction(Action.List);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    this.logger.log(ctx, `calling ${FastingRepository.name}.findAndCount`);
    const [fastings, count] = await this.repository.findAndCount({
      where: {},
      take: limit,
      skip: offset,
    });

    const fastingsOutput = plainToClass(FastingOutput, fastings, {
      excludeExtraneousValues: true,
    });

    return { fastings: fastingsOutput, count };
  }

  async getFastingById(
    ctx: RequestContext,
    id: number,
    region: Region,
  ): Promise<FastingOutput> {
    this.logger.log(ctx, `${this.getFastingById.name} was called`);

    const actor: Actor = ctx.user;

    this.logger.log(ctx, `calling ${FastingRepository.name}.getByIdAndRegion`);
    const fasting = await this.repository.getByIdAndRegion(id, region);

    const isAllowed = this.aclService
      .forActor(actor)
      .canDoAction(Action.Read, fasting);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    return plainToClass(FastingOutput, fasting, {
      excludeExtraneousValues: true,
    });
  }

  async updateFasting(
    ctx: RequestContext,
    fastingId: number,
    region: Region,
    input: UpdateFastingInput,
  ): Promise<FastingOutput> {
    this.logger.log(ctx, `${this.updateFasting.name} was called`);

    this.logger.log(ctx, `calling ${FastingRepository.name}.getByIdAndRegion`);
    const fasting = await this.repository.getByIdAndRegion(fastingId, region);

    const actor: Actor = ctx.user;

    const isAllowed = this.aclService
      .forActor(actor)
      .canDoAction(Action.Update, fasting);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    const updatedFasting: Fasting = {
      ...fasting,
      ...plainToClass(Fasting, input),
    };

    this.logger.log(ctx, `calling ${FastingRepository.name}.save`);
    const savedFasting = await this.repository.save(updatedFasting);

    return plainToClass(FastingOutput, savedFasting, {
      excludeExtraneousValues: true,
    });
  }

  async deleteFasting(
    ctx: RequestContext,
    id: number,
    region: Region,
  ): Promise<void> {
    this.logger.log(ctx, `${this.deleteFasting.name} was called`);

    this.logger.log(ctx, `calling ${FastingRepository.name}.getByIdAndRegion`);
    const fasting = await this.repository.getByIdAndRegion(id, region);

    const actor: Actor = ctx.user;

    const isAllowed = this.aclService
      .forActor(actor)
      .canDoAction(Action.Delete, fasting);
    if (!isAllowed) {
      throw new UnauthorizedException();
    }

    this.logger.log(ctx, `calling ${FastingRepository.name}.remove`);
    await this.repository.remove(fasting);
  }
}
