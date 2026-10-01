import {
  dayKeyToLabel,
  enumerateDayKeys,
  isSameLocalDay,
  localDayKey,
  parseDayKey,
} from './local-day';

const TZ = 'Africa/Tunis'; // UTC+1, no DST

describe('local-day', () => {
  describe('localDayKey', () => {
    it('uses the distribution timezone, not UTC', () => {
      // 23:30 UTC on the 12th is 00:30 on the 13th in Tunis.
      expect(localDayKey(new Date('2024-03-12T23:30:00Z'), TZ)).toBe(
        '2024-03-13',
      );
      expect(localDayKey(new Date('2024-03-12T22:59:59Z'), TZ)).toBe(
        '2024-03-12',
      );
    });
  });

  describe('isSameLocalDay', () => {
    it('is true within the same Tunis day across the UTC midnight', () => {
      expect(
        isSameLocalDay(
          new Date('2024-03-12T23:10:00Z'),
          new Date('2024-03-13T18:00:00Z'),
          TZ,
        ),
      ).toBe(true);
    });

    it('is false across the Tunis midnight', () => {
      expect(
        isSameLocalDay(
          new Date('2024-03-12T22:50:00Z'),
          new Date('2024-03-12T23:10:00Z'),
          TZ,
        ),
      ).toBe(false);
    });

    it('is false for missing or invalid dates', () => {
      expect(isSameLocalDay(null, new Date(), TZ)).toBe(false);
      expect(isSameLocalDay(new Date('nope'), new Date(), TZ)).toBe(false);
    });
  });

  describe('parseDayKey', () => {
    it('accepts ISO dates', () => {
      expect(parseDayKey('2025-03-03')).toBe('2025-03-03');
      expect(parseDayKey('2025-03-03T10:00:00.000Z')).toBe('2025-03-03');
    });

    it('accepts the legacy Date.toDateString() format', () => {
      expect(parseDayKey('Mon Mar 03 2025')).toBe('2025-03-03');
    });

    it('returns null for empty or invalid input', () => {
      expect(parseDayKey(undefined)).toBeNull();
      expect(parseDayKey('')).toBeNull();
      expect(parseDayKey('not a date')).toBeNull();
    });
  });

  it('enumerates an inclusive range across month boundaries', () => {
    expect(enumerateDayKeys('2025-02-27', '2025-03-02')).toEqual([
      '2025-02-27',
      '2025-02-28',
      '2025-03-01',
      '2025-03-02',
    ]);
    expect(enumerateDayKeys('2025-03-03', '2025-03-03')).toEqual([
      '2025-03-03',
    ]);
  });

  it('formats labels like Date.toDateString()', () => {
    expect(dayKeyToLabel('2025-03-03')).toBe('Mon Mar 03 2025');
  });
});
