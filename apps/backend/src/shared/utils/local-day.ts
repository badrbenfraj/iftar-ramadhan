/**
 * Calendar-day helpers evaluated in the distribution timezone (APP_TIMEZONE),
 * independent of the timezone the server process runs in.
 *
 * A "day key" is an ISO calendar date string: YYYY-MM-DD.
 */

export const DEFAULT_APP_TIMEZONE = 'Africa/Tunis';

const DAY_NAMES = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTH_NAMES = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const formatters = new Map<string, Intl.DateTimeFormat>();

function formatterFor(timeZone: string): Intl.DateTimeFormat {
  let formatter = formatters.get(timeZone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    formatters.set(timeZone, formatter);
  }
  return formatter;
}

const pad = (value: number): string => String(value).padStart(2, '0');

/** Calendar day (YYYY-MM-DD) of an instant, as seen in `timeZone`. */
export function localDayKey(date: Date, timeZone: string): string {
  const parts = formatterFor(timeZone).formatToParts(date);
  const get = (type: string) => parts.find((p) => p.type === type)?.value;
  return `${get('year')}-${get('month')}-${get('day')}`;
}

export function isSameLocalDay(
  a: Date | null | undefined,
  b: Date,
  timeZone: string,
): boolean {
  if (!a || isNaN(a.getTime())) {
    return false;
  }
  return localDayKey(a, timeZone) === localDayKey(b, timeZone);
}

/**
 * Parses a client-supplied calendar date into a day key.
 * Accepts `YYYY-MM-DD` (preferred) and the legacy `Date.toDateString()`
 * format (`Mon Mar 03 2025`) sent by the Ionic app. Both carry no time,
 * so the date components are taken as-is.
 */
export function parseDayKey(input?: string | null): string | null {
  if (!input) {
    return null;
  }
  const trimmed = input.trim();
  const iso = /^(\d{4})-(\d{2})-(\d{2})/.exec(trimmed);
  if (iso) {
    return `${iso[1]}-${iso[2]}-${iso[3]}`;
  }
  const parsed = new Date(trimmed);
  if (isNaN(parsed.getTime())) {
    return null;
  }
  // Date-only strings without an ISO shape are parsed in server-local time,
  // so the local getters return exactly the components that were sent.
  return `${parsed.getFullYear()}-${pad(parsed.getMonth() + 1)}-${pad(
    parsed.getDate(),
  )}`;
}

/** Inclusive list of day keys from `startKey` to `endKey`. */
export function enumerateDayKeys(startKey: string, endKey: string): string[] {
  const toUtc = (key: string) => {
    const [y, m, d] = key.split('-').map(Number);
    return Date.UTC(y, m - 1, d);
  };
  const keys: string[] = [];
  const end = toUtc(endKey);
  for (let t = toUtc(startKey); t <= end; t += 24 * 60 * 60 * 1000) {
    const day = new Date(t);
    keys.push(
      `${day.getUTCFullYear()}-${pad(day.getUTCMonth() + 1)}-${pad(
        day.getUTCDate(),
      )}`,
    );
  }
  return keys;
}

/** Legacy label format (`Date.toDateString()`), e.g. `Mon Mar 03 2025`. */
export function dayKeyToLabel(key: string): string {
  const [y, m, d] = key.split('-').map(Number);
  const day = new Date(Date.UTC(y, m - 1, d));
  return `${DAY_NAMES[day.getUTCDay()]} ${MONTH_NAMES[day.getUTCMonth()]} ${pad(
    day.getUTCDate(),
  )} ${y}`;
}
