class Region {
  const Region({
    required this.id,
    required this.name,
    this.allowOfflineServing = false,
  });

  factory Region.fromJson(Map<String, dynamic> json) => Region(
    id: (json['id'] as num).toInt(),
    name: (json['name'] as String?) ?? '',
    allowOfflineServing: json['allowOfflineServing'] == true,
  );

  final int id;
  final String name;

  /// Spec 2B: volunteers may serve with no network here. Off by default and
  /// from an older backend.
  final bool allowOfflineServing;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      other is Region && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.roles,
    required this.isAccountDisabled,
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
      isAccountDisabled: json['isAccountDisabled'] == true,
      region: region is Map<String, dynamic> ? Region.fromJson(region) : null,
    );
  }

  final int id;
  final String name;
  final String username;
  final String email;
  final List<String> roles;
  final bool isAccountDisabled;

  /// Every fasting-person call is scoped to the volunteer's region.
  final Region? region;

  bool get isAdmin => roles.contains('ADMIN');

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
    'isAccountDisabled': isAccountDisabled,
    'region': region?.toJson(),
  };
}
