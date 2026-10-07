import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/utils/formatters.dart';
import '../../auth/domain/user.dart';
import 'meal_event.dart';

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
    this.receivedAt,
    this.region,
    this.todayMeal,
    this.meals = const [],
  });

  /// [receivedAt] is when the response arrived; see [FastingPerson.receivedAt].
  /// A copy saved on the phone (see [toJson]) carries its own, under
  /// [receivedAtKey].
  factory FastingPerson.fromJson(
    Map<String, dynamic> json, {
    DateTime? receivedAt,
  }) {
    final region = json['region'];
    final lastTaken = json['lastTakenMeal'];
    final savedReceivedAt = json[receivedAtKey];
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
      receivedAt:
          receivedAt ??
          (savedReceivedAt is String
              ? DateTime.tryParse(savedReceivedAt)?.toLocal()
              : null),
      region: region is Map<String, dynamic> ? Region.fromJson(region) : null,
      todayMeal: MealEvent.tryParse(json['todayMeal']),
      meals: [
        for (final m in (json['meals'] as List?) ?? const [])
          ?MealEvent.tryParse(m),
      ],
    );
  }

  /// Key of [receivedAt] in [toJson].
  static const receivedAtKey = '_receivedAt';

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

  /// When the server flag above was received. The flag describes that
  /// calendar day only; from the next day on it is ignored and the last
  /// taken meal decides. Null (hand-built people) means "trust the flag".
  final DateTime? receivedAt;
  final Region? region;

  /// Tonight's meal as the server last described it: who served it, and its
  /// ID for Undo. Null from an older backend.
  final MealEvent? todayMeal;

  /// Every meal, newest first. Only a single-person read fills it.
  final List<MealEvent> meals;

  String get fullName => '$firstName $lastName'.trim();

  /// Portions to hand over at pickup (family meal = 4).
  int get totalPortions => singleMeal + familyMeal * 4;

  /// The server is the source of truth for the day it answered; after that
  /// (the phone gets no push at midnight) the device clock decides, from the
  /// last taken meal.
  bool isMealTakenToday([DateTime? now]) {
    final today = (now ?? DateTime.now()).toLocal();
    final flag = mealTakenTodayFromServer;
    final received = receivedAt;
    if (flag != null &&
        (received == null || isSameDay(received.toLocal(), today))) {
      return flag;
    }
    final taken = lastTakenMeal;
    if (taken == null) return false;
    return isSameDay(taken, today);
  }

  /// [todayMeal] while it can still be trusted: like the served flag, it
  /// describes the day it was received only.
  MealEvent? todayMealAt(DateTime now) {
    final meal = todayMeal;
    if (meal == null || !meal.isActive) return null;
    final received = receivedAt;
    if (received != null && !isSameDay(received.toLocal(), now.toLocal())) {
      return null;
    }
    return meal;
  }

  /// Server-shaped JSON, for the copy of the list saved on the phone
  /// (spec 2A §5.4). [receivedAt] travels with it, so a served flag still
  /// expires at midnight.
  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'cin': cin,
    'phone': phone,
    'comment': comment,
    'singleMeal': singleMeal,
    'familyMeal': familyMeal,
    'lastTakenMeal': lastTakenMeal?.toUtc().toIso8601String(),
    'takenMeals': [for (final t in takenMeals) t.toUtc().toIso8601String()],
    'mealTakenToday': mealTakenTodayFromServer,
    'todayMeal': todayMeal?.toJson(),
    'meals': [for (final m in meals) m.toJson()],
    'region': region?.toJson(),
    receivedAtKey: receivedAt?.toUtc().toIso8601String(),
  };

  FastingPerson copyWith({
    String? phone,
    String? comment,
    DateTime? lastTakenMeal,
    List<DateTime>? takenMeals,
    bool? mealTakenTodayFromServer,
    DateTime? receivedAt,
    MealEvent? todayMeal,
    bool clearTodayMeal = false,
    List<MealEvent>? meals,
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
    receivedAt: receivedAt ?? this.receivedAt,
    region: region,
    todayMeal: clearTodayMeal ? null : (todayMeal ?? this.todayMeal),
    meals: meals ?? this.meals,
  );

  /// Search by ID, names, CIN or phone. The query is split into words and
  /// every word must appear somewhere in the person's data, in any order
  /// ("fatma ali" finds "Fatma Ben Ali"). Case-, accent- and
  /// space-insensitive ("  HEDI " finds "Hédi"); Arabic is folded too
  /// (diacritics, tatweel, alef/yaa/taa-marbuta/hamza variants) and the
  /// query may use Arabic-Indic digits.
  bool matches(String query) => searchMatcher(query)(this);

  /// Prepares [query] once (folding and splitting), for filtering a list.
  static bool Function(FastingPerson) searchMatcher(String query) {
    final words = _fold(latinDigits(query))
        .split(_whitespace)
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return (_) => true;
    return (person) {
      final key = person.searchKey;
      for (final w in words) {
        if (!key.contains(w)) return false;
      }
      return true;
    };
  }

  static final Expando<String> _searchKeys = Expando<String>('searchKey');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// ID, names (both orders), CIN and phone, folded; computed once per
  /// person (the value class stays const, so the cache lives in an Expando).
  @visibleForTesting
  String get searchKey => _searchKeys[this] ??= _fold(
    latinDigits(
      [
        '$id',
        fullName,
        '$lastName $firstName',
        ?cin,
        ?phone,
        if (phone != null) phone!.replaceAll(' ', ''),
      ].join(' '),
    ),
  );

  static final Map<int, String> _folds = _buildFolds();

  static Map<int, String> _buildFolds() {
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyy';
    return {
      for (var i = 0; i < from.length; i++) from.codeUnitAt(i): to[i],
      0x153: 'oe', // œ
      0xE6: 'ae', // æ
      0x623: 'ا', 0x625: 'ا', 0x622: 'ا', 0x671: 'ا', // أ إ آ ٱ
      0x649: 'ي', // ى
      0x626: 'ي', // ئ
      0x624: 'و', // ؤ
      0x629: 'ه', // ة
    };
  }

  static String _fold(String text) {
    final out = StringBuffer();
    for (final unit in text.toLowerCase().codeUnits) {
      // Combining marks, Arabic tashkeel (064B-0652, 0670) and tatweel (0640)
      // are dropped.
      if ((unit >= 0x300 && unit <= 0x36F) ||
          (unit >= 0x64B && unit <= 0x652) ||
          unit == 0x670 ||
          unit == 0x640) {
        continue;
      }
      final mapped = _folds[unit];
      if (mapped == null) {
        out.writeCharCode(unit);
      } else {
        out.write(mapped);
      }
    }
    return out.toString();
  }
}

String? _nonEmpty(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
