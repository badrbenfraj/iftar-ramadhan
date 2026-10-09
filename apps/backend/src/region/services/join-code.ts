import { randomInt } from 'crypto';

/** Easy to say over the phone, Latin letters only (spec §4.4). */
const WORDS = [
  'NOUR', 'RAHMA', 'SABR', 'BARAKA', 'AMAL', 'SALAM', 'KHAIR', 'IHSAN',
  'HILAL', 'IFTAR', 'SUHUR', 'TAQWA', 'JANNA', 'FAJR', 'DUA', 'ZAKAT',
] as const;

/** `NOUR-482193`: a word and 6 random digits. */
export function generateJoinCode(): string {
  const word = WORDS[randomInt(WORDS.length)];
  const digits = String(randomInt(1_000_000)).padStart(6, '0');
  return `${word}-${digits}`;
}

/** What volunteers type: spaces, case and a missing dash are forgiven. */
export function normalizeJoinCode(raw: string): string {
  const compact = raw.trim().toUpperCase().replace(/[\s_]+/g, '');
  const match = /^([A-Z]+)-?(\d{6})$/.exec(compact);
  return match ? `${match[1]}-${match[2]}` : compact;
}
