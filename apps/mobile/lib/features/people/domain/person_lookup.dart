import 'fasting_person.dart';

/// Another registered person with this CIN, if any. Advisory only: it sees
/// the volunteer's region (the cached list), not the whole database.
FastingPerson? findByCin(
  Iterable<FastingPerson> people,
  String cin, {
  int? excludeId,
}) {
  final value = cin.trim();
  if (value.length != 8) return null;
  for (final p in people) {
    if (p.id != excludeId && p.cin?.trim() == value) return p;
  }
  return null;
}
