import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/utils/formatters.dart';
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
