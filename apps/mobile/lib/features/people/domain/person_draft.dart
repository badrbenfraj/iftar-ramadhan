/// Form input for creating or editing a person, with the Ionic validation
/// rules made explicit and testable.
class PersonDraft {
  const PersonDraft({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.singleMeal,
    required this.familyMeal,
    this.cin,
    this.phone,
    this.comment,
    this.cameToday = true,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String? cin;
  final String? phone;
  final String? comment;
  final int singleMeal;
  final int familyMeal;

  /// Only used on creation: record today's meal immediately.
  final bool cameToday;
}

abstract final class PersonRules {
  static const cinLength = 8;
  static const maxId = 2147483647; // PostgreSQL integer

  static const mealsError =
      'Single meal or Family meal should be greater than 0';

  static String? validateId(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'Identifier is required';
    final id = int.tryParse(value);
    if (id == null || id <= 0 || id > maxId) {
      return 'Identifier must be a positive whole number';
    }
    return null;
  }

  static String? validateRequired(String? raw, String label) =>
      (raw == null || raw.trim().isEmpty) ? '$label is required' : null;

  /// CIN is optional but must be exactly 8 characters when given.
  static String? validateCin(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    return value.length == cinLength ? null : 'CIN must be 8 characters';
  }

  static String? validateMealCount(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final n = int.tryParse(value);
    if (n == null || n < 0) return 'Enter a whole number (0 or more)';
    return null;
  }

  /// Ionic rule: at least one of single/family must be > 0; an empty one
  /// becomes 0. Returns the normalized pair, or null when invalid.
  static ({int single, int family})? normalizeMeals(
    String? single,
    String? family,
  ) {
    final s = int.tryParse(single?.trim() ?? '') ?? 0;
    final f = int.tryParse(family?.trim() ?? '') ?? 0;
    if (s < 0 || f < 0) return null;
    if (s == 0 && f == 0) return null;
    return (single: s, family: f);
  }
}
