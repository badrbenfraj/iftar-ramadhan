import 'package:dio/dio.dart';

/// Every error surfaced to the UI is one of these. Screens switch on the type
/// to decide what to show (e.g. "no connection" vs "already collected").
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// Human-readable, volunteer-facing message.
  final String message;

  /// Whether retrying the same action can reasonably succeed.
  bool get isRetryable => false;

  @override
  String toString() => '$runtimeType: $message';
}

/// The device could not reach the server (offline, DNS, refused, TLS).
final class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'No internet connection. Check your network and try again.',
  ]);

  @override
  bool get isRetryable => true;
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure([
    super.message = 'The server is taking too long to respond. Try again.',
  ]);

  @override
  bool get isRetryable => true;
}

/// 401 — bad credentials on login, or an expired session elsewhere.
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure([
    super.message = 'Your session has expired. Please sign in again.',
  ]);
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([
    super.message = 'You are not allowed to perform this action.',
  ]);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Not found.']);
}

/// 409 with a machine-readable `code` from the API (`error.details.code`).
final class ConflictFailure extends AppFailure {
  const ConflictFailure(super.message, {this.code});

  final String? code;
}

/// The person already collected today's meal (409 MEAL_ALREADY_TAKEN).
final class MealAlreadyTakenFailure extends ConflictFailure {
  const MealAlreadyTakenFailure({this.takenAt})
    : super('Meal already collected today', code: codeValue);

  static const codeValue = 'MEAL_ALREADY_TAKEN';

  final DateTime? takenAt;
}

/// 400 — the server rejected the input.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// 5xx or an unexpected response.
final class ServerFailure extends AppFailure {
  const ServerFailure({this.statusCode})
    : super('Something went wrong on the server. Try again in a moment.');

  final int? statusCode;

  @override
  bool get isRetryable => true;
}

/// A precondition of the app itself (e.g. the account has no region).
final class AppStateFailure extends AppFailure {
  const AppStateFailure(super.message);
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message = 'Unexpected error. Try again.']);

  @override
  bool get isRetryable => true;
}

/// Maps anything thrown by the data layer into an [AppFailure].
AppFailure toAppFailure(Object error) {
  if (error is AppFailure) return error;
  if (error is DioException) return _fromDio(error);
  return const UnknownFailure();
}

AppFailure _fromDio(DioException e) {
  final wrapped = e.error;
  if (wrapped is AppFailure) return wrapped;

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return const UnknownFailure('Request cancelled.');
    case DioExceptionType.unknown:
      // SocketException / HandshakeException etc. surface here on mobile.
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      return failureFromResponse(e.response?.statusCode, e.response?.data);
  }
}

/// Parses the API error envelope:
/// `{ "error": { "statusCode", "message", "details": { "code", "message" } } }`.
AppFailure failureFromResponse(int? status, Object? body) {
  final error = body is Map ? body['error'] : null;
  final details = error is Map ? error['details'] : null;
  final code = details is Map ? details['code'] as String? : null;
  final message = _extractMessage(error, details);

  switch (status) {
    case 400:
      return ValidationFailure(message ?? 'Some fields are invalid.');
    case 401:
      return UnauthorizedFailure(
        message == null || message == 'Unauthorized'
            ? const UnauthorizedFailure().message
            : message,
      );
    case 403:
      return const ForbiddenFailure();
    case 404:
      return NotFoundFailure(message ?? 'Not found.');
    case 409:
      if (code == MealAlreadyTakenFailure.codeValue) {
        final at = details is Map ? details['lastTakenMeal'] : null;
        return MealAlreadyTakenFailure(
          takenAt: at is String ? DateTime.tryParse(at)?.toLocal() : null,
        );
      }
      return ConflictFailure(message ?? 'Conflict.', code: code);
  }
  if (status != null && status >= 500) {
    return ServerFailure(statusCode: status);
  }
  return ServerFailure(statusCode: status);
}

String? _extractMessage(Object? error, Object? details) {
  // class-validator errors arrive as a list in details.message.
  final detailMessage = details is Map ? details['message'] : null;
  if (detailMessage is List && detailMessage.isNotEmpty) {
    return detailMessage.map((m) => '$m').join('\n');
  }
  if (detailMessage is String && detailMessage.isNotEmpty) return detailMessage;
  final message = error is Map ? error['message'] : null;
  if (message is String && message.isNotEmpty) return message;
  return null;
}
