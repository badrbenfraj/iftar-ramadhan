import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'network/api_client.dart';
import 'network/app_failure.dart';
import 'network/auth_interceptor.dart';
import 'network/connectivity.dart';
import 'storage/session_storage.dart';

/// Dependency-injection roots. Tests override these with fakes.

final appConfigProvider = Provider<AppConfig>(
  (_) => AppConfig.fromEnvironment(),
);

final sessionStorageProvider = Provider<SessionStorage>(
  (_) => SecureSessionStorage(),
);

/// Emits why the server ended the session; the auth controller signs out.
final sessionExpiredEventsProvider = Provider<StreamController<AppFailure>>((
  ref,
) {
  final controller = StreamController<AppFailure>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

final dioProvider = Provider<Dio>((ref) {
  final options = ApiClient.baseOptions(
    ref.watch(appConfigProvider).apiBaseUrl,
  );
  final events = ref.watch(sessionExpiredEventsProvider);
  final dio = Dio(options)
    ..interceptors.add(
      AuthInterceptor(
        storage: ref.watch(sessionStorageProvider),
        refreshClient: Dio(options),
        onSessionExpired: (reason) {
          if (!events.isClosed) events.add(reason);
        },
      ),
    )
    ..interceptors.add(
      ConnectivityInterceptor(
        onOnline: () => ref.read(connectivityProvider.notifier).reportOnline(),
        onOffline: () =>
            ref.read(connectivityProvider.notifier).reportOffline(),
      ),
    );
  ref.onDispose(dio.close);
  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(dioProvider)),
);

/// Injectable clock so "today" logic is testable.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);
