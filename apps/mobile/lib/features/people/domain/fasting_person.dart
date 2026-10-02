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

  /// Search by ID, names in any order, CIN or phone; case-, accent- and
  /// space-insensitive ("  HEDI " finds "Hédi"). Arabic is folded too
  /// (diacritics, tatweel, alef/yaa/taa-marbuta variants) and the query may
  /// use Arabic-Indic digits.
  bool matches(String query) {
    final q = _fold(latinDigits(query).trim());
    if (q.isEmpty) return true;
    return '$id'.contains(q) ||
        _fold(fullName).contains(q) ||
        _fold('$lastName $firstName').contains(q) ||
        (cin != null && _fold(latinDigits(cin!)).contains(q)) ||
        (phone != null &&
            _fold(latinDigits(phone!)).replaceAll(' ', '').contains(q.replaceAll(' ', '')));
  }

  static String _fold(String text) {
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyy';
    final out = StringBuffer();
    for (final ch in text.toLowerCase().split('')) {
      final unit = ch.codeUnitAt(0);
      // Arabic tashkeel (064B-0652, 0670) and tatweel (0640): dropped.
      if ((unit >= 0x064B && unit <= 0x0652) || unit == 0x0670 || unit == 0x0640) {
        continue;
      }
      switch (ch) {
        case 'أ' || 'إ' || 'آ' || 'ٱ':
          out.write('ا');
        case 'ى':
          out.write('ي');
        case 'ة':
          out.write('ه');
        default:
          final i = from.indexOf(ch);
          out.write(i < 0 ? ch : to[i]);
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
