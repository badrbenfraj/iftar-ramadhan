import { compareSemver, normalizeSemver, parseSemver } from './semver';

describe('semver', () => {
  it('compares numerically, not as text', () => {
    expect(compareSemver('1.9.0', '1.10.0')).toBeLessThan(0);
    expect(compareSemver('1.10.0', '1.9.0')).toBeGreaterThan(0);
    expect(compareSemver('2.0.0', '1.99.99')).toBeGreaterThan(0);
    expect(compareSemver('1.5.0', 'v1.5.0')).toBe(0);
  });

  it('normalizes and rejects malformed versions', () => {
    expect(normalizeSemver(' v1.5.0\n')).toBe('1.5.0');
    expect(parseSemver('1.2')).toBeNull();
    expect(parseSemver('1.2.x')).toBeNull();
    expect(parseSemver(150)).toBeNull();
    expect(() => compareSemver('1.0.0', 'latest')).toThrow();
  });
});
