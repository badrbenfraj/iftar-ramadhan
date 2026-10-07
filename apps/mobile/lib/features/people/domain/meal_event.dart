/// One meal handed over, as the server recorded it (spec 2A §4).
class MealEvent {
  const MealEvent({
    required this.eventId,
    required this.servedAt,
    this.servedById,
    this.servedByName,
    this.revokedAt,
  });

  factory MealEvent.fromJson(Map<String, dynamic> json) {
    final servedBy = json['servedBy'];
    final revoked = json['revokedAt'];
    final name = servedBy is Map ? servedBy['name'] : null;
    return MealEvent(
      eventId: json['eventId'] as String,
      servedAt: DateTime.parse(json['servedAt'] as String).toLocal(),
      servedById: servedBy is Map ? (servedBy['id'] as num?)?.toInt() : null,
      servedByName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : null,
      revokedAt: revoked is String
          ? DateTime.tryParse(revoked)?.toLocal()
          : null,
    );
  }

  /// Null for anything that isn't a well-formed meal: one bad entry must not
  /// hide the person.
  static MealEvent? tryParse(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return MealEvent.fromJson(json);
    } on Object {
      return null;
    }
  }

  final String eventId;
  final DateTime servedAt;

  /// Null for history recorded before served-by existed.
  final int? servedById;
  final String? servedByName;

  /// Set once undone.
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'servedAt': servedAt.toUtc().toIso8601String(),
    'servedBy': servedById == null
        ? null
        : {'id': servedById, 'name': servedByName ?? ''},
    'revokedAt': revokedAt?.toUtc().toIso8601String(),
  };
}
