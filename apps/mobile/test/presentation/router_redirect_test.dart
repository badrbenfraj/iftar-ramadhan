import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/router/app_router.dart';
import 'package:iftar_mobile/features/auth/domain/user.dart';

import '../support/fakes.dart';

void main() {
  const signedOut = AsyncData<User?>(null);
  const signedIn = AsyncData<User?>(testUser);
  const restoring = AsyncLoading<User?>();

  test('restoring the session shows the splash', () {
    expect(authRedirect(restoring, '/people'), '/splash');
    expect(authRedirect(restoring, '/splash'), isNull);
  });

  test('signed-out users only reach public screens', () {
    expect(authRedirect(signedOut, '/people'), '/welcome');
    expect(authRedirect(signedOut, '/scan'), '/welcome');
    expect(authRedirect(signedOut, '/splash'), '/welcome');
    expect(authRedirect(signedOut, '/login'), isNull);
    expect(authRedirect(signedOut, '/register'), isNull);
  });

  test('signed-in users skip the auth screens', () {
    expect(authRedirect(signedIn, '/login'), '/people');
    expect(authRedirect(signedIn, '/welcome'), '/people');
    expect(authRedirect(signedIn, '/splash'), '/people');
    expect(authRedirect(signedIn, '/scan'), isNull);
    expect(authRedirect(signedIn, '/people/12'), isNull);
  });
}
