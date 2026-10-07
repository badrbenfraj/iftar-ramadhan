/**
 * Minimal `major.minor.patch` handling for release metadata. Compared number
 * by number, so 1.9.0 < 1.10.0 (string comparison gets this wrong).
 */
const SEMVER = /^v?(\d+)\.(\d+)\.(\d+)$/;

export function parseSemver(input: unknown): [number, number, number] | null {
  if (typeof input !== 'string') return null;
  const m = SEMVER.exec(input.trim());
  return m ? [Number(m[1]), Number(m[2]), Number(m[3])] : null;
}

/** Normalised `1.5.0` (no `v`), or null when not a plain semver. */
export function normalizeSemver(input: unknown): string | null {
  const v = parseSemver(input);
  return v ? v.join('.') : null;
}

/** Negative when a < b, 0 when equal, positive when a > b. */
export function compareSemver(a: string, b: string): number {
  const va = parseSemver(a);
  const vb = parseSemver(b);
  if (!va || !vb) throw new Error(`Not a semver: ${va ? b : a}`);
  for (let i = 0; i < 3; i++) {
    if (va[i] !== vb[i]) return va[i] - vb[i];
  }
  return 0;
}
