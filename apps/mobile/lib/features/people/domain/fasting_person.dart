import '../../auth/domain/user.dart';

/// A registered beneficiary. `singleMeal` / `familyMeal` are how many of each
/// the person receives per pickup; a family meal counts as 4 portions.
class FastingPerson {
  const FastingPerson({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.singleMeal,
    required this.familyMeal,
    this.cin,
    this.phone,
    this.comment,
    this.lastTakenMeal,
    this.takenMeals = const [],
    this.mealTakenTodayFromServer,
    this.region,
  });

  factory FastingPerson.fromJson(Map<String, dynamic> json) {
    final region = json['region'];
    final lastTaken = json['lastTakenMeal'];
    return FastingPerson(
      id: (json['id'] as num).toInt(),
      firstName: ((json['firstName'] as String?) ?? '').trim(),
      lastName: ((json['lastName'] as String?) ?? '').trim(),
      cin: _nonEmpty(json['cin']),
      phone: _nonEmpty(json['phone']),
      comment: _nonEmpty(json['comment']),
      singleMeal: (json['singleMeal'] as num?)?.toInt() ?? 0,
      familyMeal: (json['familyMeal'] as num?)?.toInt() ?? 0,
      lastTakenMeal: lastTaken is String
          ? DateTime.tryParse(lastTaken)?.toLocal()
          : null,
      takenMeals:
          ((json['takenMeals'] as List?) ?? const [])
              .map((e) => e is String ? DateTime.tryParse(e)?.toLocal() : null)
              .whereType<DateTime>()
              .toList()
            ..sort((a, b) => b.compareTo(a)),
      mealTakenTodayFromServer: json['mealTakenToday'] as bool?,
      region: region is Map<String, dynamic> ? Region.fromJson(region) : null,
    );
  }

  final int id;
  final String firstName;
  final String lastName;
  final String? cin;
  final String? phone;
  final String? comment;
  final int singleMeal;
  final int familyMeal;
  final DateTime? lastTakenMeal;

  /// Most recent first.
  final List<DateTime> takenMeals;

  /// Server-computed (APP_TIMEZONE). Null when talking to an older backend.
  final bool? mealTakenTodayFromServer;
  final Region? region;

  String get fullName => '$firstName $lastName'.trim();

  /// Portions to hand over at pickup (family meal = 4).
  int get totalPortions => singleMeal + familyMeal * 4;

  /// The server is the source of truth; the device clock is only a fallback.
  bool isMealTakenToday([DateTime? now]) {
    if (mealTakenTodayFromServer != null) return mealTakenTodayFromServer!;
    final taken = lastTakenMeal;
    if (taken == null) return false;
    final today = (now ?? DateTime.now()).toLocal();
    return taken.year == today.year &&
        taken.month == today.month &&
        taken.day == today.day;
  }

  FastingPerson copyWith({
    String? phone,
    String? comment,
    DateTime? lastTakenMeal,
    List<DateTime>? takenMeals,
    bool? mealTakenTodayFromServer,
  }) => FastingPerson(
    id: id,
    firstName: firstName,
    lastName: lastName,
    cin: cin,
    phone: phone ?? this.phone,
    comment: comment ?? this.comment,
    singleMeal: singleMeal,
    familyMeal: familyMeal,
    lastTakenMeal: lastTakenMeal ?? this.lastTakenMeal,
    takenMeals: takenMeals ?? this.takenMeals,
    mealTakenTodayFromServer:
        mealTakenTodayFromServer ?? this.mealTakenTodayFromServer,
    region: region,
  );

  /// Search used by the people list ("search by Name or Id").
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '$id'.contains(q) ||
        fullName.toLowerCase().contains(q) ||
        '$lastName $firstName'.toLowerCase().contains(q) ||
        (cin?.toLowerCase().contains(q) ?? false) ||
        (phone?.replaceAll(' ', '').contains(q.replaceAll(' ', '')) ?? false);
  }
}

String? _nonEmpty(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
