import 'package:dio/dio.dart';

import 'app_failure.dart';

/// Thin wrapper around Dio for the `{ data, meta }` response envelope.
/// All errors are rethrown as [AppFailure].
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  static BaseOptions baseOptions(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
  );

  /// Confirm and undo normally answer fast. When they don't, a retry is
  /// safe (same clientEventId), so give up sooner than the 20 s default
  /// (spec 2A §5.1).
  static const mutationTimeout = Duration(seconds: 15);

  Future<ApiEnvelope> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? extra,
  }) => _send(
    () => _dio.get<dynamic>(
      path,
      queryParameters: query,
      options: Options(extra: extra),
    ),
  );

  Future<ApiEnvelope> post(
    String path, {
    Object? body,
    Map<String, dynamic>? extra,
    Duration? timeout,
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: body,
      options: Options(
        extra: extra,
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    ),
  );

  Future<ApiEnvelope> patch(String path, {Object? body, Duration? timeout}) =>
      _send(
        () => _dio.patch<dynamic>(
          path,
          data: body,
          options: Options(sendTimeout: timeout, receiveTimeout: timeout),
        ),
      );

  Future<ApiEnvelope> delete(String path) =>
      _send(() => _dio.delete<dynamic>(path));

  Future<ApiEnvelope> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      return ApiEnvelope.from(response.data);
    } catch (e) {
      throw toAppFailure(e);
    }
  }
}

class ApiEnvelope {
  const ApiEnvelope(this.data, this.meta);

  factory ApiEnvelope.from(Object? body) {
    if (body is Map<String, dynamic>) {
      final meta = body['meta'];
      return ApiEnvelope(
        body['data'],
        meta is Map<String, dynamic> ? meta : const {},
      );
    }
    return ApiEnvelope(body, const {});
  }

  final Object? data;
  final Map<String, dynamic> meta;

  Map<String, dynamic> get object {
    final value = data;
    if (value is Map<String, dynamic>) return value;
    throw const ServerFailure();
  }

  List<Map<String, dynamic>> get list {
    final value = data;
    if (value is List) return value.whereType<Map<String, dynamic>>().toList();
    throw const ServerFailure();
  }
}
