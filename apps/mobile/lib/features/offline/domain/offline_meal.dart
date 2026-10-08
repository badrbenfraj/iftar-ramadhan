/// A meal served with no network, waiting to sync (spec 2B §5.1). Person ID
/// and times only: the queue holds no names.
class PendingMeal {
  const PendingMeal({
    required this.clientEventId,
    required this.personId,
    required this.regionId,
    required this.servedAt,
    required this.userId,
    this.deviceId,
  });

  factory PendingMeal.fromJson(Map<String, dynamic> json) => PendingMeal(
    clientEventId: json['clientEventId'] as String,
    personId: (json['personId'] as num).toInt(),
    regionId: (json['regionId'] as num).toInt(),
    servedAt: DateTime.parse(json['servedAt'] as String).toLocal(),
    userId: (json['userId'] as num).toInt(),
    deviceId: json['deviceId'] as String?,
  );

  final String clientEventId;
  final int personId;
  final int regionId;

  /// Device time of the hand-over.
  final DateTime servedAt;

  /// The volunteer who served it; only they sync it.
  final int userId;
  final String? deviceId;

  Map<String, dynamic> toJson() => {
    'clientEventId': clientEventId,
    'personId': personId,
    'regionId': regionId,
    'servedAt': servedAt.toUtc().toIso8601String(),
    'userId': userId,
    'deviceId': deviceId,
  };

  /// One item of `POST /fastings/meals/sync`.
  Map<String, dynamic> toSyncJson() => {
    'clientEventId': clientEventId,
    'fastingId': personId,
    'regionId': regionId,
    'servedAt': servedAt.toUtc().toIso8601String(),
    'deviceId': ?deviceId,
  };
}

enum MealSyncStatus { applied, duplicate, conflict, rejected }

/// The server's answer for one synced meal (spec 2B §4.1).
class MealSyncResult {
  const MealSyncResult({
    required this.clientEventId,
    required this.status,
    this.code,
    this.flag,
    this.otherServedAt,
    this.otherServedByName,
  });

  factory MealSyncResult.fromJson(Map<String, dynamic> json) {
    final other = json['other'];
    final servedBy = other is Map ? other['servedBy'] : null;
    final at = other is Map ? other['servedAt'] : null;
    final name = servedBy is Map ? servedBy['name'] : null;
    return MealSyncResult(
      clientEventId: json['clientEventId'] as String,
      status: MealSyncStatus.values.asNameMap()[json['status']],
      code: json['code'] as String?,
      flag: json['flag'] as String?,
      otherServedAt: at is String ? DateTime.tryParse(at)?.toLocal() : null,
      otherServedByName:
          name is String && name.trim().isNotEmpty ? name.trim() : null,
    );
  }

  final String clientEventId;

  /// Null for a status this app doesn't know: the meal stays queued.
  final MealSyncStatus? status;
  final String? code;
  final String? flag;
  final DateTime? otherServedAt;
  final String? otherServedByName;
}

/// A synced meal the volunteer should see: a double serve, or a meal the
/// server could not record (spec 2B §5.3). Acknowledged on the phone only;
/// admins resolve it.
class ReviewItem {
  const ReviewItem({
    required this.clientEventId,
    required this.personId,
    required this.servedAt,
    required this.userId,
    required this.conflict,
    this.code,
    this.otherServedAt,
    this.otherServedByName,
  });

  factory ReviewItem.from(PendingMeal meal, MealSyncResult result) =>
      ReviewItem(
        clientEventId: meal.clientEventId,
        personId: meal.personId,
        servedAt: meal.servedAt,
        userId: meal.userId,
        conflict: result.status == MealSyncStatus.conflict,
        code: result.code,
        otherServedAt: result.otherServedAt,
        otherServedByName: result.otherServedByName,
      );

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    final other = json['otherServedAt'];
    return ReviewItem(
      clientEventId: json['clientEventId'] as String,
      personId: (json['personId'] as num).toInt(),
      servedAt: DateTime.parse(json['servedAt'] as String).toLocal(),
      userId: (json['userId'] as num).toInt(),
      conflict: json['conflict'] == true,
      code: json['code'] as String?,
      otherServedAt: other is String ? DateTime.tryParse(other)?.toLocal() : null,
      otherServedByName: json['otherServedByName'] as String?,
    );
  }

  static const clockCode = 'CLOCK_OUT_OF_RANGE';
  static const notFoundCode = 'PERSON_NOT_FOUND';
  static const regionCode = 'REGION_NOT_ALLOWED';

  final String clientEventId;
  final int personId;
  final DateTime servedAt;
  final int userId;

  /// True: a second meal the same day. False: not recorded, see [code].
  final bool conflict;
  final String? code;
  final DateTime? otherServedAt;
  final String? otherServedByName;

  Map<String, dynamic> toJson() => {
    'clientEventId': clientEventId,
    'personId': personId,
    'servedAt': servedAt.toUtc().toIso8601String(),
    'userId': userId,
    'conflict': conflict,
    'code': code,
    'otherServedAt': otherServedAt?.toUtc().toIso8601String(),
    'otherServedByName': otherServedByName,
  };
}
