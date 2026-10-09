import { SetMetadata } from '@nestjs/common';

export const SKIP_REGION_CHECK_KEY = 'skipRegionCheck';

/** The route has no `:region`; it checks access in the service instead. */
export const SkipRegionCheck = (): MethodDecorator & ClassDecorator =>
  SetMetadata(SKIP_REGION_CHECK_KEY, true);
