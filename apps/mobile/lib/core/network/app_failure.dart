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

/// 401 on login: wrong username or password.
final class InvalidCredentialsFailure extends UnauthorizedFailure {
  const InvalidCredentialsFailure() : super('Wrong username or password.');
}

/// The account exists but an administrator disabled it.
final class AccountDisabledFailure extends UnauthorizedFailure {
  const AccountDisabledFailure() : super('This account has been disabled.');

  static const code = 'ACCOUNT_DISABLED';
}

/// Registered without a join code; a coordinator has not approved it yet.
final class AccountPendingFailure extends UnauthorizedFailure {
  const AccountPendingFailure()
    : super('This account is waiting for approval.');

  static const code = 'ACCOUNT_PENDING';
}

class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure([
    super.message = 'You are not allowed to perform this action.',
  ]);

  /// The account can't act in that region (security spec §2).
  static const regionForbidden = 'REGION_FORBIDDEN';
}

/// 403 on undo: someone else's meal, or too late (spec 2A §4.2).
final class UndoRefusedFailure extends ForbiddenFailure {
  const UndoRefusedFailure(this.code)
    : super('This meal can no longer be undone.');

  static const windowExpired = 'UNDO_WINDOW_EXPIRED';
  static const notAllowed = 'UNDO_NOT_ALLOWED';

  final String code;

  bool get tooLate => code == windowExpired;
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message = 'Not found.']);
}

/// 409 with a machine-readable `code` from the API (`error.details.code`).
final class ConflictFailure extends AppFailure {
  const ConflictFailure(super.message, {this.code});

  static const usernameTaken = 'USERNAME_TAKEN';

  final String? code;
}

/// The person already collected today's meal (409 MEAL_ALREADY_TAKEN).
final class MealAlreadyTakenFailure extends ConflictFailure {
  const MealAlreadyTakenFailure({this.takenAt, this.servedByName})
    : super('Meal already collected today', code: codeValue);

  static const codeValue = 'MEAL_ALREADY_TAKEN';

  final DateTime? takenAt;

  /// Who served it, when the server knows (spec 2A §4.1).
  final String? servedByName;
}

/// 400 — the server rejected the input.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// 400 INVALID_JOIN_CODE on register.
final class InvalidJoinCodeFailure extends ValidationFailure {
  const InvalidJoinCodeFailure() : super('This join code is not valid.');

  static const code = 'INVALID_JOIN_CODE';
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
  const AppStateFailure(super.message, {this.code});

  static const noRegion = 'NO_REGION';

  final String? code;
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
      if (code == InvalidJoinCodeFailure.code) {
        return const InvalidJoinCodeFailure();
      }
      return ValidationFailure(message ?? 'Some fields are invalid.');
    case 401:
      if (code == AccountPendingFailure.code) {
        return const AccountPendingFailure();
      }
      if (code == AccountDisabledFailure.code) {
        return const AccountDisabledFailure();
      }
      return UnauthorizedFailure(
        message == null || message == 'Unauthorized'
            ? const UnauthorizedFailure().message
            : message,
      );
    case 403:
      if (code == UndoRefusedFailure.windowExpired ||
          code == UndoRefusedFailure.notAllowed) {
        return UndoRefusedFailure(code!);
      }
      return const ForbiddenFailure();
    case 404:
      return NotFoundFailure(message ?? 'Not found.');
    case 409:
      if (code == MealAlreadyTakenFailure.codeValue) {
        final at = details is Map
            ? (details['servedAt'] ?? details['lastTakenMeal'])
            : null;
        final servedBy = details is Map ? details['servedBy'] : null;
        final name = servedBy is Map ? servedBy['name'] : null;
        return MealAlreadyTakenFailure(
          takenAt: at is String ? DateTime.tryParse(at)?.toLocal() : null,
          servedByName: name is String && name.trim().isNotEmpty
              ? name.trim()
              : null,
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
