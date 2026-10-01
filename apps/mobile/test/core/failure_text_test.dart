import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/network/failure_text.dart';

import '../support/app_harness.dart';

void main() {
  final cases = <(AppFailure, String)>[
    (const InvalidCredentialsFailure(), en.errLoginFailed),
    (const AccountDisabledFailure(), en.errAccountDisabled),
    (const UnauthorizedFailure(), en.errSessionExpired),
    (const NetworkFailure(), en.errNetwork),
    (const TimeoutFailure(), en.errTimeout),
    (const ForbiddenFailure(), en.errForbidden),
    (const NotFoundFailure(), en.errNotFound),
    (const MealAlreadyTakenFailure(), en.alreadyCollected),
    (const ConflictFailure('x', code: ConflictFailure.usernameTaken), en.errUsernameTaken),
    (const ConflictFailure('Card 12 exists'), 'Card 12 exists'),
    (const ValidationFailure('Phone must be 8 digits'), 'Phone must be 8 digits'),
    (const ServerFailure(statusCode: 500), en.errServer),
    (const AppStateFailure('x', code: AppStateFailure.noRegion), en.errNoRegion),
    (const AppStateFailure('Something specific'), 'Something specific'),
    (const UnknownFailure(), en.errUnknown),
  ];

  for (final (failure, expected) in cases) {
    test('${failure.runtimeType} → "$expected"', () {
      expect(failureText(en, failure), expected);
    });
  }

  test('Arabic text is used in Arabic', () {
    expect(failureText(ar, const NetworkFailure()), ar.errNetwork);
    expect(ar.errNetwork, isNot(en.errNetwork));
  });

  test('titles for full-screen errors', () {
    expect(failureTitle(en, const NetworkFailure()), en.titleOffline);
    expect(failureTitle(en, const ForbiddenFailure()), en.titleGenericError);
  });
}
