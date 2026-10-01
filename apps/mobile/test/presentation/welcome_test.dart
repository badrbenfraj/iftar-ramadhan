import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/settings/settings_controller.dart';
import 'package:iftar_mobile/core/settings/settings_storage.dart';
import 'package:iftar_mobile/core/widgets/brand.dart';
import 'package:iftar_mobile/features/auth/presentation/welcome_page.dart';

import '../support/app_harness.dart';
import '../support/fonts.dart';

void main() {
  late MemorySettingsStorage storage;
  setUpAll(loadAppFonts);
  setUp(() => storage = MemorySettingsStorage());

  Widget app(Locale locale) => localizedApp(
    const WelcomePage(),
    locale: locale,
    overrides: [settingsStorageProvider.overrideWithValue(storage)],
  );

  /// Pumps Welcome on a [size] screen at text [scale], with the logo image
  /// decoded so it takes its real height.
  Future<void> pumpAt(
    WidgetTester tester,
    String code, {
    required Size size,
    required double scale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.runAsync(() async {
      final done = Completer<void>();
      const AssetImage('assets/images/ramadan.png')
          .resolve(ImageConfiguration(devicePixelRatio: 1, bundle: rootBundle))
          .addListener(ImageStreamListener((_, _) => done.complete()));
      await done.future;
    });
    await tester.pumpWidget(app(Locale(code)));
  }

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

  testWidgets('language pills are at least 48 px tall', (tester) async {
    await tester.pumpWidget(app(const Locale('en')));
    for (final name in ['English', 'Français', 'العربية']) {
      final pill = find.ancestor(
        of: find.text(name),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(pill).height, greaterThanOrEqualTo(48), reason: name);
    }
  });

  testWidgets('Arabic hadith and title are not letter-spaced', (tester) async {
    await tester.pumpWidget(app(const Locale('ar')));
    for (final text in [hadithText, ar.appTitle]) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(paragraph.text.style?.letterSpacing ?? 0, 0, reason: text);
    }
  });

  for (final code in ['en', 'fr', 'ar']) {
    testWidgets('fits at 360x760, text scale 1.3 ($code)', (tester) async {
      await pumpAt(tester, code, size: const Size(360, 760), scale: 1.3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits at 360x640, text scale 2.0 ($code)', (tester) async {
      await pumpAt(tester, code, size: const Size(360, 640), scale: 2.0);
      expect(tester.takeException(), isNull);
    });
  }
}
