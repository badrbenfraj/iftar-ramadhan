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
 * Who may undo a meal (spec 2A §4.2, widened by the security spec §2):
 * the volunteer who served it, within `windowMinutes` of the server
 * receiving it; or an admin of the meal's region (`canAdminister`), on the
 * meal's own service day. Undoing twice is not an error.
 */
export function decideRevoke(
  event: RevocableEvent,
  actor: { id: number },
  now: Date,
  opts: { windowMinutes: number; timeZone: string; canAdminister: boolean },
): RevokeDecision {
  if (event.revokedAt) {
    return 'alreadyRevoked';
  }
  if (
    opts.canAdminister &&
    event.serviceDay === localDayKey(now, opts.timeZone)
  ) {
    return 'allowed';
  }
  if (event.servedByUserId !== actor.id) {
    return opts.canAdminister ? 'windowExpired' : 'notAllowed';
  }
  const ageMs = now.getTime() - new Date(event.receivedAt).getTime();
  return ageMs <= opts.windowMinutes * 60_000 ? 'allowed' : 'windowExpired';
}
