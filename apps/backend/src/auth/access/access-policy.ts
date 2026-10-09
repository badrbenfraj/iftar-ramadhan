import { ForbiddenException } from '@nestjs/common';

import { ROLE } from '../constants/role.constant';
import { AUTH_ERROR_CODES } from './auth-error-codes';

/** The request user as the policy sees it (fresh from the database). */
export interface AccessUser {
  id: number;
  roles: string[];
  regionId?: number | null;
}

/**
 * Every access right in one place (security spec §2–3.2).
 * Global admin: everything. Regional admin and volunteer: their own region
 * only. No region means no access (fail closed).
 */
export function isGlobalAdmin(user: AccessUser): boolean {
  return user.roles.includes(ROLE.ADMIN);
}

export function canAccessRegion(user: AccessUser, regionId: number): boolean {
  if (isGlobalAdmin(user)) return true;
  return user.regionId != null && Number(user.regionId) === Number(regionId);
}

export function isRegionAdmin(user: AccessUser, regionId: number): boolean {
  if (isGlobalAdmin(user)) return true;
  return (
    user.roles.includes(ROLE.REGION_ADMIN) && canAccessRegion(user, regionId)
  );
}

export function isAnyAdmin(user: AccessUser): boolean {
  return isGlobalAdmin(user) || user.roles.includes(ROLE.REGION_ADMIN);
}

/**
 * Approve, refuse, disable or enable `target`. A regional admin manages only
 * plain volunteers of their own region; nobody manages themselves here.
 */
export function canManageUser(
  actor: AccessUser,
  target: { id: number; roles: string[]; regionId: number | null },
): boolean {
  if (actor.id === target.id) return false;
  if (isGlobalAdmin(actor)) return true;
  if (!actor.roles.includes(ROLE.REGION_ADMIN)) return false;
  const plainVolunteer = target.roles.every((r) => r === ROLE.USER);
  return (
    plainVolunteer &&
    target.regionId != null &&
    canAccessRegion(actor, target.regionId)
  );
}

export function regionForbidden(): ForbiddenException {
  return new ForbiddenException({
    message: 'You cannot act in this region',
    code: AUTH_ERROR_CODES.REGION_FORBIDDEN,
  });
}
