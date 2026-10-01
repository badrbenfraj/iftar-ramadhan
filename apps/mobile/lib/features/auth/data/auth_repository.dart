import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/providers.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/user.dart';

abstract interface class AuthRepository {
  /// Cached user from secure storage, if a session exists.
  Future<User?> restoreSession();
  Future<User> login(String username, String password);
  Future<User> fetchProfile();
  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required int regionId,
  });
  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._storage);

  final ApiClient _api;
  final SessionStorage _storage;

  static const _public = {skipAuthKey: true};

  @override
  Future<User?> restoreSession() async {
    final token = await _storage.readAccessToken();
    final user = await _storage.readUser();
    if (token == null || user == null) return null;
    try {
      return User.fromJson(user);
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }

  @override
  Future<User> login(String username, String password) async {
    try {
      final envelope = await _api.post(
        '/auth/login',
        body: {'username': username.trim(), 'password': password},
        extra: _public,
      );
      final tokens = envelope.object;
      await _storage.saveTokens(
        accessToken: tokens['accessToken'] as String,
        refreshToken: tokens['refreshToken'] as String?,
      );
    } on UnauthorizedFailure catch (e) {
      final disabled = e.message.toLowerCase().contains('disabled');
      throw UnauthorizedFailure(
        disabled
            ? 'This account has been disabled.'
            : 'Wrong username or password.',
      );
    }

    final user = await fetchProfile();
    if (user.isAccountDisabled) {
      await _storage.clear();
      throw const UnauthorizedFailure('This account has been disabled.');
    }
    return user;
  }

  @override
  Future<User> fetchProfile() async {
    final envelope = await _api.get('/users/me');
    final json = envelope.object;
    await _storage.saveUser(json);
    return User.fromJson(json);
  }

  @override
  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required int regionId,
  }) async {
    try {
      await _api.post(
        '/auth/register',
        body: {
          'name': name.trim(),
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
          'region': {'id': regionId},
        },
        extra: _public,
      );
    } on ConflictFailure {
      throw const ConflictFailure('Username or email is already in use');
    }
  }

  @override
  Future<void> logout() => _storage.clear();
}

abstract interface class RegionRepository {
  Future<List<Region>> listRegions();
}

class ApiRegionRepository implements RegionRepository {
  ApiRegionRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Region>> listRegions() async {
    final envelope = await _api.get(
      '/regions',
      query: {'limit': 1000, 'offset': 0},
      extra: {skipAuthKey: true},
    );
    return envelope.list.map(Region.fromJson).toList();
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);

final regionRepositoryProvider = Provider<RegionRepository>(
  (ref) => ApiRegionRepository(ref.watch(apiClientProvider)),
);
