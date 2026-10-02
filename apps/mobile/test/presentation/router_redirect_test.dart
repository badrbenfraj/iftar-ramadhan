import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iftar_mobile/core/router/app_router.dart';
import 'package:iftar_mobile/core/settings/settings_controller.dart';
import 'package:iftar_mobile/core/settings/settings_storage.dart';
import 'package:iftar_mobile/features/auth/domain/user.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/session_summary_page.dart';
import 'package:iftar_mobile/l10n/app_localizations.dart';

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

  test('nothing shows before the saved settings are in', () {
    expect(authRedirect(signedIn, '/people', settingsReady: false), '/splash');
    expect(authRedirect(signedOut, '/welcome', settingsReady: false), '/splash');
    expect(authRedirect(signedIn, '/splash', settingsReady: false), isNull);
    expect(authRedirect(restoring, '/splash', settingsReady: false), isNull);
  });

  test('signed-in users skip the auth screens', () {
    expect(authRedirect(signedIn, '/login'), '/people');
    expect(authRedirect(signedIn, '/welcome'), '/people');
    expect(authRedirect(signedIn, '/splash'), '/people');
    expect(authRedirect(signedIn, '/scan'), isNull);
    expect(authRedirect(signedIn, '/people/12'), isNull);
  });

  group('real /summary route', () {
    Future<GoRouter> boot(WidgetTester tester) async {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          ...testOverrides(FakePeopleRepository([person(1)])),
          // The router waits for the saved settings.
          settingsStorageProvider.overrideWithValue(MemorySettingsStorage()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/find');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/find');
      return router;
    }

    String path(GoRouter router) => router.state.uri.path;

    testWidgets('without an extra it lands on /people', (tester) async {
      final router = await boot(tester);
      router.go('/summary');
      await tester.pumpAndSettle();
      expect(path(router), '/people');
    });

    testWidgets('with a wrong-type extra it lands on /people', (tester) async {
      final router = await boot(tester);
      router.go('/summary', extra: 'not a summary');
      await tester.pumpAndSettle();
      expect(path(router), '/people');
    });

    testWidgets('with a SessionSummary it stays on /summary', (tester) async {
      final router = await boot(tester);
      router.go(
        '/summary',
        extra: const SessionSummary(served: 3, singleMeals: 1, familyMeals: 2),
      );
      await tester.pumpAndSettle();
      expect(path(router), '/summary');
    });
  });
}
