import { Injectable } from '@nestjs/common';

import { canAccessRegion } from '../../auth/access/access-policy';
import { ROLE } from '../../auth/constants/role.constant';
import { BaseAclService } from '../../shared/acl/acl.service';
import { Action } from '../../shared/acl/action.constant';
import { Actor } from '../../shared/acl/actor.constant';
import { Fasting } from '../entities/fasting.entity';

/**
 * Security spec §2: volunteers create, read and edit in their own region;
 * regional admins also delete there; global admins do everything. The
 * RegionAccessGuard has already checked the URL region; this re-checks the
 * loaded person, so a wrong join can never leak another region.
 */
@Injectable()
export class FastingAclService extends BaseAclService<Fasting> {
  constructor() {
    super();
    this.canDo(ROLE.ADMIN, [Action.Manage]);
    this.canDo(ROLE.REGION_ADMIN, [Action.Manage], this.isInActorRegion);
    this.canDo(
      ROLE.USER,
      [Action.Create, Action.List, Action.Read, Action.Update],
      this.isInActorRegion,
    );
  }

  isInActorRegion(fasting: Fasting | undefined, actor: Actor): boolean {
    // List/Create pass no resource: the guard checked the region.
    if (!fasting) return true;
    const regionId = fasting.region?.id;
    return regionId != null && canAccessRegion(actor, regionId);
  }
}
