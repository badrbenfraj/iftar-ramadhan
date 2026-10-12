class Region {
  const Region({
    required this.id,
    required this.name,
    this.allowOfflineServing = true,
    this.active = true,
  });

  factory Region.fromJson(Map<String, dynamic> json) => Region(
    id: (json['id'] as num).toInt(),
    name: (json['name'] as String?) ?? '',
    allowOfflineServing: json['allowOfflineServing'] != false,
    active: json['active'] != false,
  );

  final int id;
  final String name;

  /// Spec 2B: volunteers may serve with no network here. On unless an admin
  /// turned it off for the region.
  final bool allowOfflineServing;

  /// False once an admin closed it: read-only, its volunteers are blocked.
  final bool active;

  /// Saved with the signed-in user, so the flag still holds when the app
  /// starts with no network.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'allowOfflineServing': allowOfflineServing,
    'active': active,
  };

  @override
  bool operator ==(Object other) =>
      other is Region &&
      other.id == id &&
      other.name == name &&
      other.active == active;

  @override
  int get hashCode => Object.hash(id, name, active);
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.roles,
    this.status = 'active',
    this.region,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final region = json['region'];
    return User(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      roles: ((json['roles'] as List?) ?? const []).map((r) => '$r').toList(),
      status:
          (json['status'] as String?) ??
          (json['isAccountDisabled'] == true ? 'disabled' : 'active'),
      region: region is Map<String, dynamic> ? Region.fromJson(region) : null,
    );
  }

  final int id;
  final String name;
  final String username;
  final String email;
  final List<String> roles;
  final String status;

  /// Every fasting-person call is scoped to the volunteer's region.
  final Region? region;

  bool get isAdmin => roles.contains('ADMIN');

  bool get isAccountDisabled => status == 'disabled';

  /// Coordinator of [region] (security spec §2).
  bool get isRegionAdmin => roles.contains('REGION_ADMIN');

  /// An admin closed their region: the app shows only "region closed".
  /// Global admins keep working everywhere.
  bool get isRegionClosed => !isAdmin && region != null && !region!.active;

  /// Sees Profile → Volunteers.
  bool get canManageVolunteers => isAdmin || isRegionAdmin;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts
        .take(2)
        .map((p) => String.fromCharCode(p.runes.first))
        .join();
    return letters.isEmpty ? '?' : letters.toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'username': username,
    'email': email,
    'roles': roles,
    'status': status,
    'region': region?.toJson(),
  };
}
