import 'package:dio/dio.dart';

import '../storage/session_storage.dart';

/// Marks a request that must not carry or refresh credentials (login, register).
const skipAuthKey = 'skipAuth';
const _retriedKey = 'authRetried';

/// Adds the bearer token and transparently refreshes it once on 401, so
/// volunteers are not logged out in the middle of a distribution.
/// Requests are queued while a refresh is in flight.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required this.storage,
    required this.refreshClient,
    required this.onSessionExpired,
  });

  final SessionStorage storage;

  /// A bare client (no interceptors) used for the refresh call and retries.
  final Dio refreshClient;
  final void Function() onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final token = await storage.readAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    if (!isUnauthorized ||
        options.extra[skipAuthKey] == true ||
        options.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    try {
      // Another queued request may already have refreshed the token.
      final usedHeader = options.headers['Authorization'];
      var token = await storage.readAccessToken();
      if (token == null || usedHeader == 'Bearer $token') {
        token = await _refresh();
      }
      if (token == null) {
        onSessionExpired();
        return handler.next(err);
      }

      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_retriedKey] = true;
      final response = await refreshClient.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      if (retryError.response?.statusCode == 401) onSessionExpired();
      return handler.next(retryError);
    }
  }

  Future<String?> _refresh() async {
    final refreshToken = await storage.readRefreshToken();
    if (refreshToken == null) return null;
    try {
      final response = await refreshClient.post<Map<String, dynamic>>(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) return null;
      final accessToken = data['accessToken'] as String?;
      if (accessToken == null) return null;
      await storage.saveTokens(
        accessToken: accessToken,
        refreshToken: data['refreshToken'] as String?,
      );
      return accessToken;
    } on DioException catch (e) {
      // Offline while refreshing: keep the session, surface the network error.
      if (e.response == null) rethrow;
      return null;
    }
  }
}
