import { ROLE } from '../../auth/constants/role.constant';
import { localDayKey } from '../../shared/utils/local-day';

export type RevokeDecision =
  | 'allowed'
  | 'alreadyRevoked'
  | 'notAllowed'
  | 'windowExpired';

export interface RevocableEvent {
  servedByUserId: number | null;
  receivedAt: Date;
  /** YYYY-MM-DD in APP_TIMEZONE. */
  serviceDay: string;
  revokedAt: Date | null;
}

/**
 * Who may undo a meal (spec 2A §4.2): the volunteer who served it, within
 * `windowMinutes` of the server receiving it; or an admin, on the meal's own
 * service day. Undoing twice is not an error.
 */
export function decideRevoke(
  event: RevocableEvent,
  actor: { id: number; roles: string[] },
  now: Date,
  opts: { windowMinutes: number; timeZone: string },
): RevokeDecision {
  if (event.revokedAt) {
    return 'alreadyRevoked';
  }
  const isAdmin = actor.roles.includes(ROLE.ADMIN);
  if (isAdmin && event.serviceDay === localDayKey(now, opts.timeZone)) {
    return 'allowed';
  }
  if (event.servedByUserId !== actor.id) {
    return isAdmin ? 'windowExpired' : 'notAllowed';
  }
  const ageMs = now.getTime() - new Date(event.receivedAt).getTime();
  return ageMs <= opts.windowMinutes * 60_000 ? 'allowed' : 'windowExpired';
}
