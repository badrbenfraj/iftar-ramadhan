import '../../../core/utils/formatters.dart';

enum StatsPeriod {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  custom('Custom');

  const StatsPeriod(this.label);

  final String label;

  /// Same ranges as the Ionic app: the week runs Sunday → Saturday and the
  /// month from the 1st to its last day. `custom` keeps the given range.
  ({DateTime from, DateTime to}) rangeFor(
    DateTime now, {
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    final today = dateOnly(now);
    switch (this) {
      case StatsPeriod.daily:
        return (from: today, to: today);
      case StatsPeriod.weekly:
        // DateTime.weekday: Mon=1 … Sun=7  →  days since Sunday.
        final sinceSunday = today.weekday % 7;
        final start = DateTime(
          today.year,
          today.month,
          today.day - sinceSunday,
        );
        return (
          from: start,
          to: DateTime(start.year, start.month, start.day + 6),
        );
      case StatsPeriod.monthly:
        return (
          from: DateTime(today.year, today.month),
          to: DateTime(today.year, today.month + 1, 0),
        );
      case StatsPeriod.custom:
        return (from: customFrom ?? today, to: customTo ?? today);
    }
  }
}

class DailyStatistics {
  const DailyStatistics({
    required this.label,
    required this.totalPersons,
    required this.persons,
    required this.singleMeal,
    required this.familyMeal,
    required this.totalMeals,
  });

  factory DailyStatistics.fromJson(Map<String, dynamic> json) {
    final s = (json['statistics'] as Map?)?.cast<String, dynamic>() ?? {};
    int n(String key) => (s[key] as num?)?.toInt() ?? 0;
    return DailyStatistics(
      label: (json['date'] as String?) ?? '',
      totalPersons: n('totalPersons'),
      persons: n('persons'),
      singleMeal: n('singleMeal'),
      familyMeal: n('familyMeal'),
      totalMeals: n('totalMeals'),
    );
  }

  /// Server label, e.g. "Mon Mar 03 2025".
  final String label;
  final int totalPersons;

  /// Served persons that day.
  final int persons;
  final int singleMeal;

  /// Family meals already expressed in portions (×4) by the server.
  final int familyMeal;
  final int totalMeals;
}

class StatisticsSummary {
  const StatisticsSummary(this.days);

  final List<DailyStatistics> days;

  int get persons => days.fold(0, (sum, d) => sum + d.persons);
  int get singleMeal => days.fold(0, (sum, d) => sum + d.singleMeal);
  int get familyMeal => days.fold(0, (sum, d) => sum + d.familyMeal);
  int get totalMeals => days.fold(0, (sum, d) => sum + d.totalMeals);
}
