import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/providers.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/user.dart';

/// Whether a new account can sign in now or waits for a coordinator.
enum RegisterOutcome { active, pending }

/// What sign-up returns: the outcome and the region the code belongs to.
typedef RegisterResult = ({RegisterOutcome outcome, String? regionName});

abstract interface class AuthRepository {
  /// Cached user from secure storage, if a session exists.
  Future<User?> restoreSession();
  Future<User> login(String username, String password);
  Future<User> fetchProfile();
  /// The join code picks the region (regions are never listed publicly).
  Future<RegisterResult> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required String joinCode,
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
    } on AccountPendingFailure {
      rethrow;
    } on AccountDisabledFailure {
      rethrow;
    } on UnauthorizedFailure {
      throw const InvalidCredentialsFailure();
    }

    final user = await fetchProfile();
    if (user.isAccountDisabled) {
      await _storage.clear();
      throw const AccountDisabledFailure();
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
  Future<RegisterResult> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required String joinCode,
  }) async {
    try {
      final envelope = await _api.post(
        '/auth/register',
        body: {
          'name': name.trim(),
          'username': username.trim(),
          'email': email.trim(),
          'password': password,
          'joinCode': joinCode.trim(),
        },
        extra: _public,
      );
      final account = envelope.object;
      final region = account['region'];
      return (
        outcome: account['status'] == 'pending'
            ? RegisterOutcome.pending
            : RegisterOutcome.active,
        regionName: region is Map ? region['name'] as String? : null,
      );
    } on ConflictFailure {
      throw const ConflictFailure(
        'Username or email is already in use',
        code: ConflictFailure.usernameTaken,
      );
    }
  }

  @override
  Future<void> logout() => _storage.clear();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStorageProvider),
  ),
);
