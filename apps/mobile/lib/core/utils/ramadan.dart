/// Day of Ramadan (1–30) for [now], counted from the season's official first
/// day ([start], set at build time). Null when not configured or out of range.
int? ramadanDay(DateTime? start, DateTime now) {
  if (start == null) return null;
  // UTC dates avoid daylight-saving off-by-one in `inDays`.
  final first = DateTime.utc(start.year, start.month, start.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final day = today.difference(first).inDays + 1;
  return day >= 1 && day <= 30 ? day : null;
}
