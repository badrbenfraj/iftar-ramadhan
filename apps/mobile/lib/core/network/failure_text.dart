import '../../l10n/app_localizations.dart';
import 'app_failure.dart';

/// The volunteer-facing message for [failure], in the UI language. Server
/// validation and conflict messages are already human text and pass through.
String failureText(AppLocalizations l, AppFailure failure) => switch (failure) {
  InvalidCredentialsFailure() => l.errLoginFailed,
  AccountPendingFailure() => l.errAccountPending,
  AccountDisabledFailure() => l.errAccountDisabled,
  UnauthorizedFailure() => l.errSessionExpired,
  NetworkFailure() => l.errNetwork,
  TimeoutFailure() => l.errTimeout,
  ForbiddenFailure() => l.errForbidden,
  NotFoundFailure() => l.errNotFound,
  MealAlreadyTakenFailure() => l.alreadyCollected,
  ConflictFailure(code: ConflictFailure.usernameTaken) => l.errUsernameTaken,
  ConflictFailure(:final message) => message,
  InvalidJoinCodeFailure() => l.errInvalidJoinCode,
  ValidationFailure(:final message) => message,
  TooManyRequestsFailure() => l.errTooManyRequests,
  ServerFailure() => l.errServer,
  AppStateFailure(code: AppStateFailure.noRegion) => l.errNoRegion,
  AppStateFailure(:final message) => message,
  UnknownFailure() => l.errUnknown,
};

/// Short title for full-screen error views.
String failureTitle(AppLocalizations l, AppFailure failure) => switch (failure) {
  NetworkFailure() => l.titleOffline,
  TimeoutFailure() => l.titleSlow,
  ServerFailure() => l.titleServerError,
  UnauthorizedFailure() => l.titleSignedOut,
  NotFoundFailure() => l.titleNotFound,
  _ => l.titleGenericError,
};
