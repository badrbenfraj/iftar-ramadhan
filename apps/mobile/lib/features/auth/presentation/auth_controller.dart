import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// `AsyncData(null)` = signed out; `AsyncData(user)` = signed in;
/// `AsyncLoading` = restoring the session at startup.
class AuthController extends AsyncNotifier<User?> {
  StreamSubscription<void>? _expirySub;

  /// Set when the user was signed out by the server (shown on the login page).
  AppFailure? lastSignOutFailure;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<User?> build() async {
    _expirySub = ref
        .watch(sessionExpiredEventsProvider)
        .stream
        .listen((_) => _signOut(reason: const UnauthorizedFailure()));
    ref.onDispose(() => _expirySub?.cancel());

    final cached = await _repo.restoreSession();
    if (cached != null) {
      // Refresh the profile (region may have changed) without blocking
      // startup; offline, the cached profile keeps the app usable.
      unawaited(_refreshProfile());
    }
    return cached;
  }

  Future<void> _refreshProfile() async {
    try {
      final user = await _repo.fetchProfile();
      if (state.value != null) state = AsyncData(user);
    } on AppFailure {
      // Network errors: keep the cached user. 401 is handled by the
      // interceptor via the session-expired event.
    }
  }

  Future<void> login(String username, String password) async {
    lastSignOutFailure = null;
    final user = await _repo.login(username, password);
    state = AsyncData(user);
  }

  Future<void> logout() => _signOut();

  Future<void> _signOut({AppFailure? reason}) async {
    if (state.value == null && reason != null) return;
    lastSignOutFailure = reason;
    await _repo.logout();
    state = const AsyncData(null);
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, User?>(
  AuthController.new,
);

/// The signed-in user's region; every fasting-person call is scoped to it.
Region requireRegion(Ref ref) => regionOf(ref.read(authControllerProvider));

Region regionOf(AsyncValue<User?> auth) {
  final region = auth.value?.region;
  if (region == null) {
    throw const AppStateFailure(
      'Your account has no region assigned. Ask an administrator.',
      code: AppStateFailure.noRegion,
    );
  }
  return region;
}
