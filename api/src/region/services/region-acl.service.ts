import { Injectable } from '@nestjs/common';

import { ROLE } from '../../auth/constants/role.constant';
import { BaseAclService } from '../../shared/acl/acl.service';
import { Action } from '../../shared/acl/action.constant';
import { Actor } from '../../shared/acl/actor.constant';
import { Region } from '../entities/region.entity';

@Injectable()
export class RegionAclService extends BaseAclService<Region> {
  constructor() {
    super();
    this.canDo(ROLE.ADMIN, [Action.Manage]);
    this.canDo(ROLE.USER, [Action.Update, Action.Delete], this.isRegionAuthor);
  }

  isRegionAuthor(region: Region, user: Actor): boolean {
    return region.createdBy.id === user.id;
  }
}
