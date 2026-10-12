import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { plainToClass } from 'class-transformer';
import { ILike, Not } from 'typeorm';

import {
  canAccessRegion,
  isGlobalAdmin,
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
import { AdminRegionOutput } from '../dtos/admin-region-output.dto';
import { JoinCodeOutput } from '../dtos/join-code-output.dto';
import { PublicRegionOutput } from '../dtos/public-region-output.dto';
import {
  CloseRegionInput,
  CreateRegionInput,
  UpdateRegionInput,
} from '../dtos/region-input.dto';
import { RegionOutput } from '../dtos/region-output.dto';
import { RegionUsageOutput } from '../dtos/region-usage-output.dto';
import { Region } from '../entities/region.entity';
import { RegionRepository } from '../repositories/region.repository';
import { generateJoinCode } from './join-code';
import { RegionAclService } from './region-acl.service';

/** 409 code when a region would reuse an existing name (any case). */
export const REGION_NAME_TAKEN = 'REGION_NAME_TAKEN';

/** 409 code when deleting a region that people, users or meals point to. */
export const REGION_IN_USE = 'REGION_IN_USE';

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

    region.name = region.name.trim();
    await this.assertNameFree(region.name);

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

    const changes: Partial<Region> = {};
    const name = input.name?.trim();
    if (name && name !== region.name) {
      await this.assertNameFree(name, id);
      changes.name = name;
    }
    if (input.allowOfflineServing !== undefined) {
      changes.allowOfflineServing = input.allowOfflineServing;
    }

    // update(), not save(): the name is part of the primary key, so save()
    // would insert a copy. Users and fastings follow (ON UPDATE CASCADE).
    if (Object.keys(changes).length > 0) {
      this.logger.log(ctx, `calling ${RegionRepository.name}.update`);
      await this.repository.update({ id }, changes);
    }

    return plainToClass(
      RegionOutput,
      await this.repository.getRegionById(id),
      { excludeExtraneousValues: true },
    );
  }

  /** Global admins: every region, closed ones included, by name. */
  async getAllRegions(ctx: RequestContext): Promise<AdminRegionOutput[]> {
    this.logger.log(ctx, `${this.getAllRegions.name} was called`);
    if (!isGlobalAdmin(ctx.user)) throw regionForbidden();
    const regions = await this.repository.find({ order: { name: 'ASC' } });
    return plainToClass(AdminRegionOutput, regions, {
      excludeExtraneousValues: true,
    });
  }

  async getUsage(ctx: RequestContext, id: number): Promise<RegionUsageOutput> {
    if (!isGlobalAdmin(ctx.user)) throw regionForbidden();
    await this.repository.getRegionById(id);
    return this.usage(id);
  }

  /**
   * Stops serving in the region; its people and meals stay, read-only. Its
   * volunteers and coordinators are blocked until moved, optionally all at
   * once to `input.moveUsersTo`.
   */
  async closeRegion(
    ctx: RequestContext,
    id: number,
    input: CloseRegionInput,
  ): Promise<AdminRegionOutput> {
    this.logger.log(ctx, `${this.closeRegion.name} was called`);
    if (!isGlobalAdmin(ctx.user)) throw regionForbidden();
    const region = await this.repository.getRegionById(id);
    if (!region.active) return this.adminOutput(region);

    const target =
      input.moveUsersTo == null
        ? null
        : await this.repository.findOne({ where: { id: input.moveUsersTo } });
    if (input.moveUsersTo != null && (!target || !target.active)) {
      throw new BadRequestException('Pick an open region to move users to');
    }
    if (target?.id === id) {
      throw new BadRequestException('Pick another region to move users to');
    }

    await this.repository.manager.transaction(async (manager) => {
      await manager.update(
        Region,
        { id },
        { active: false, closedAt: new Date() },
      );
      if (target) {
        await manager.query(
          `UPDATE "users"
              SET "regionId" = $2, "regionName" = $3, "previousRegionId" = $1
            WHERE "regionId" = $1`,
          [id, target.id, target.name],
        );
      }
    });
    return this.adminOutput(await this.repository.getRegionById(id));
  }

  async reopenRegion(
    ctx: RequestContext,
    id: number,
  ): Promise<AdminRegionOutput> {
    this.logger.log(ctx, `${this.reopenRegion.name} was called`);
    if (!isGlobalAdmin(ctx.user)) throw regionForbidden();
    await this.repository.getRegionById(id);
    await this.repository.update({ id }, { active: true, closedAt: null });
    return this.adminOutput(await this.repository.getRegionById(id));
  }

  /** Only an empty region (e.g. created by mistake); otherwise close it. */
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

    const usage = await this.usage(id);
    if (usage.users + usage.people + usage.meals > 0) {
      throw new ConflictException({
        message: 'This region is in use; close it instead',
        code: REGION_IN_USE,
        ...usage,
      });
    }

    this.logger.log(ctx, `calling ${RegionRepository.name}.delete`);
    await this.repository.delete({ id });
  }

  private async assertNameFree(name: string, exceptId?: number): Promise<void> {
    const taken = await this.repository.findOne({
      where: {
        name: ILike(name.replace(/[\\%_]/g, '\\$&')),
        ...(exceptId == null ? {} : { id: Not(exceptId) }),
      },
    });
    if (taken) {
      throw new ConflictException({
        message: 'A region with this name already exists',
        code: REGION_NAME_TAKEN,
      });
    }
  }

  private async usage(id: number): Promise<RegionUsageOutput> {
    const [row]: Array<{ users: string; people: string; meals: string }> =
      await this.repository.query(
        `SELECT
           (SELECT count(*) FROM "users" WHERE "regionId" = $1) AS "users",
           (SELECT count(*) FROM "fastings" WHERE "regionId" = $1) AS "people",
           (SELECT count(*) FROM "meal_events" WHERE "regionId" = $1) AS "meals"`,
        [id],
      );
    return {
      users: Number(row.users),
      people: Number(row.people),
      meals: Number(row.meals),
    };
  }

  private adminOutput(region: Region): AdminRegionOutput {
    return plainToClass(AdminRegionOutput, region, {
      excludeExtraneousValues: true,
    });
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
