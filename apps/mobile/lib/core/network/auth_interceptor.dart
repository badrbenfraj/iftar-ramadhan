import 'package:dio/dio.dart';

import '../storage/session_storage.dart';
import 'app_failure.dart';

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
    this.onRegionForbidden,
  });

  final SessionStorage storage;

  /// A bare client (no interceptors) used for the refresh call and retries.
  final Dio refreshClient;
  final void Function(AppFailure reason) onSessionExpired;
  /// Called on a 403 REGION_FORBIDDEN (the account may have been moved).
  final void Function()? onRegionForbidden;
  AppFailure? _refreshFailure;

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
    if (err.response?.statusCode == 403 && _isRegionForbidden(err.response)) {
      onRegionForbidden?.call();
    }
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
        onSessionExpired(_sessionEndReason(err));
        return handler.next(err);
      }

      options.headers['Authorization'] = 'Bearer $token';
      options.extra[_retriedKey] = true;
      final response = await refreshClient.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (retryError) {
      if (retryError.response?.statusCode == 401) {
        onSessionExpired(_sessionEndReason(retryError));
      }
      return handler.next(retryError);
    }
  }

  bool _isRegionForbidden(Response<dynamic>? response) {
    final data = response?.data;
    final error = data is Map ? data['error'] : null;
    final details = error is Map ? error['details'] : null;
    return details is Map &&
        details['code'] == ForbiddenFailure.regionForbidden;
  }

  /// Disabled or pending accounts get their own message on the login page.
  AppFailure _sessionEndReason(DioException err) {
    final fromResponse = failureFromResponse(
      err.response?.statusCode,
      err.response?.data,
    );
    final reason = _refreshFailure ?? fromResponse;
    return reason is UnauthorizedFailure ? reason : const UnauthorizedFailure();
  }

  Future<String?> _refresh() async {
    _refreshFailure = null;
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
      // Offline, rate limited or a server error while refreshing: temporary,
      // keep the session and surface the error. Only 401/403 ends it.
      final status = e.response?.statusCode;
      if (status == null || status == 429 || status >= 500) rethrow;
      _refreshFailure = failureFromResponse(
        e.response?.statusCode,
        e.response?.data,
      );
      return null;
    }
  }
}
