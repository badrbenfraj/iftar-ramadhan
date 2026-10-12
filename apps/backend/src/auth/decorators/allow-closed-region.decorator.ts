import { SetMetadata } from '@nestjs/common';

export const ALLOW_CLOSED_REGION_KEY = 'allowClosedRegion';

/**
 * Users of a closed region may still call this route: reading their profile
 * (the app shows "region closed") and syncing meals served before closure.
 */
export const AllowClosedRegion = (): MethodDecorator & ClassDecorator =>
  SetMetadata(ALLOW_CLOSED_REGION_KEY, true);
