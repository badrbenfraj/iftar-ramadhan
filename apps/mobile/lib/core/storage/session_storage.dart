import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens and the cached profile, kept in the platform keystore
/// (Android Keystore / iOS Keychain) — never in plain preferences.
abstract interface class SessionStorage {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<Map<String, dynamic>?> readUser();
  Future<void> saveTokens({required String accessToken, String? refreshToken});
  Future<void> saveUser(Map<String, dynamic> user);
  Future<void> clear();
}

class SecureSessionStorage implements SessionStorage {
  SecureSessionStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'user';

  // In-memory cache: the auth interceptor reads the token on every request.
  String? _accessToken;
  bool _accessTokenLoaded = false;

  @override
  Future<String?> readAccessToken() async {
    if (!_accessTokenLoaded) {
      _accessToken = await _storage.read(key: _accessTokenKey);
      _accessTokenLoaded = true;
    }
    return _accessToken;
  }

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<Map<String, dynamic>?> readUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    _accessToken = accessToken;
    _accessTokenLoaded = true;
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  @override
  Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: _userKey, value: jsonEncode(user));

  @override
  Future<void> clear() async {
    _accessToken = null;
    _accessTokenLoaded = true;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }
}
