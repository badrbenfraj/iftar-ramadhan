import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/app.dart';
import 'package:iftar_mobile/core/settings/settings_controller.dart';
import 'package:iftar_mobile/core/settings/settings_storage.dart';
import 'package:iftar_mobile/features/auth/presentation/welcome_page.dart';
import 'package:iftar_mobile/features/people/presentation/people_list_page.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

/// Reads wait for [gate], like a slow keychain at startup.
class _SlowReadStorage extends MemorySettingsStorage {
  final gate = Completer<void>();

  @override
  Future<String?> read(String key) async {
    await gate.future;
    return super.read(key);
  }
}

void main() {
  setUpAll(loadAppFonts);

  Future<_SlowReadStorage> boot(WidgetTester tester, {bool signedIn = true}) async {
    final storage = _SlowReadStorage()..values[SettingsController.localeKey] = 'ar';
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          ...testOverrides(FakePeopleRepository([person(1)]), user: signedIn ? testUser : null),
          settingsStorageProvider.overrideWithValue(storage),
        ],
        child: const IftarApp(),
      ),
    );
    return storage;
  }

  /// The splash spinner never settles, so advance by frames.
  Future<void> held(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the splash holds until the saved settings are in, then the app opens in them', (tester) async {
    final storage = await boot(tester);
    await held(tester);
    // The session is restored already; only the settings are late.
    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.byType(PeopleListPage), findsNothing);

    storage.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(PeopleListPage), findsOneWidget);
    expect(find.text(ar.navPeople), findsWidgets, reason: 'first real frame is in the saved language');
    expect(find.text(en.navPeople), findsNothing);
  });

  testWidgets('signed out, the welcome page does not show before the settings', (tester) async {
    final storage = await boot(tester, signedIn: false);
    await held(tester);
    expect(find.byType(WelcomePage), findsNothing);

    storage.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.text(ar.signIn), findsOneWidget);
  });
}
