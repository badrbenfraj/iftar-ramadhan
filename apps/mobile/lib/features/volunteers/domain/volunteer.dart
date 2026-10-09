import '../../auth/domain/user.dart';

/// One account as the Volunteers screen sees it.
class Volunteer {
  const Volunteer({
    required this.id,
    required this.name,
    required this.username,
    required this.status,
    required this.roles,
    required this.joinedWithCode,
    this.region,
  });

  factory Volunteer.fromJson(Map<String, dynamic> json) {
    final region = json['region'];
    return Volunteer(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      roles: ((json['roles'] as List?) ?? const []).map((r) => '$r').toList(),
      joinedWithCode: json['joinedWithCode'] == true,
      region: region is Map<String, dynamic> ? Region.fromJson(region) : null,
    );
  }

  final int id;
  final String name;
  final String username;

  /// `pending`, `active` or `disabled`.
  final String status;
  final List<String> roles;
  final bool joinedWithCode;
  final Region? region;

  bool get isCoordinator => roles.contains('REGION_ADMIN');
  bool get isGlobalAdmin => roles.contains('ADMIN');
}
