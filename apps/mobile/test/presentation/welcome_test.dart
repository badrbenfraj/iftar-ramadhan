import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/settings/settings_controller.dart';
import 'package:iftar_mobile/core/settings/settings_storage.dart';
import 'package:iftar_mobile/features/auth/presentation/welcome_page.dart';

import '../support/app_harness.dart';

void main() {
  late MemorySettingsStorage storage;
  setUp(() => storage = MemorySettingsStorage());

  Widget app(Locale locale) => localizedApp(
    const WelcomePage(),
    locale: locale,
    overrides: [settingsStorageProvider.overrideWithValue(storage)],
  );

  testWidgets('offers the three languages and both actions', (tester) async {
    await tester.pumpWidget(app(const Locale('en')));
    for (final name in ['English', 'Français', 'العربية']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text(en.signIn), findsOneWidget);
    expect(find.text(en.createVolunteerAccount), findsOneWidget);
    expect(find.text(en.hadithMeaning), findsOneWidget);
    expect(find.bySemanticsLabel('Ramadan Kareem'), findsOneWidget); // logo kept
  });

  testWidgets('picking a language saves it', (tester) async {
    await tester.pumpWidget(app(const Locale('en')));
    await tester.tap(find.text('Français'));
    await tester.pump();
    expect(storage.values[SettingsController.localeKey], 'fr');
  });

  testWidgets('Arabic hides the translated hadith line', (tester) async {
    await tester.pumpWidget(app(const Locale('ar')));
    expect(find.text(en.hadithMeaning), findsNothing);
    expect(find.text(ar.signIn), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('layout with multiple locales at 1.3x text scale', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;

    for (final locale in [const Locale('en'), const Locale('fr'), const Locale('ar')]) {
      // ignore: prefer_const_constructors
      await tester.pumpWidget(
        // ignore: prefer_const_constructors
        MediaQuery(
          // ignore: prefer_const_constructors
          data: MediaQueryData(
            size: const Size(360, 760),
            // ignore: prefer_const_constructors
            textScaler: TextScaler.linear(1.3),
          ),
          child: app(locale),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'No overflow in ${locale.languageCode}');
    }
  }, skip: true);
}
