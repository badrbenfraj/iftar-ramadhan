import { Injectable } from '@nestjs/common';

import { ROLE } from '../../auth/constants/role.constant';
import { BaseAclService } from '../../shared/acl/acl.service';
import { Action } from '../../shared/acl/action.constant';
import { Actor } from '../../shared/acl/actor.constant';
import { Fasting } from '../entities/fasting.entity';

@Injectable()
export class FastingAclService extends BaseAclService<Fasting> {
  constructor() {
    super();
    this.canDo(ROLE.ADMIN, [Action.Manage]);
    this.canDo(ROLE.USER, [Action.Create, Action.List, Action.Read]);
    this.canDo(ROLE.USER, [Action.Update, Action.Delete], this.isFastingAuthor);
  }

  isFastingAuthor(fasting: Fasting, user: Actor): boolean {
    return fasting.createdBy.id === user.id;
  }
}
