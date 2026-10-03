import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/network/failure_text.dart';
import 'package:iftar_mobile/core/utils/formatters.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/people/presentation/person_details_page.dart';
import 'package:iftar_mobile/l10n/app_localizations.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

/// The app's router resolves the session before any page; do the same here.
Widget _afterSignIn(Widget page) => Consumer(
  builder: (context, ref, _) =>
      ref.watch(authControllerProvider).hasValue ? page : const SizedBox(),
);

void main() {
  setUpAll(loadAppFonts);

  testWidgets('an eligible person can be served from details', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Haptics go through the platform channel, which has no host in tests.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final repo = FakePeopleRepository([person(101)]);
    await tester.pumpWidget(localizedApp(
      _afterSignIn(const PersonDetailsPage(personId: 101)),
      overrides: testOverrides(repo),
    ));
    await tester.pumpAndSettle();
    expect(find.text(en.detailsTitle), findsOneWidget);
    await tester.tap(find.text(en.confirmMeal));
    await tester.pumpAndSettle();
    expect(find.text(en.mealConfirmed), findsOneWidget);
    expect(repo.confirmCalls, 1);
  });

  testWidgets('already served today cannot be served again', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakePeopleRepository([person(102, takenToday: true)]);
    await tester.pumpWidget(localizedApp(
      _afterSignIn(const PersonDetailsPage(personId: 102)),
      overrides: testOverrides(repo),
    ));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.text(en.alreadyServedToday), matching: find.byType(FilledButton)),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('names are shown isolated', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakePeopleRepository([person(103, first: 'Najwa', last: 'Chalbi')]);
    await tester.pumpWidget(localizedApp(
      _afterSignIn(const PersonDetailsPage(personId: 103)),
      overrides: testOverrides(repo),
    ));
    await tester.pumpAndSettle();
    expect(find.text(isolate('Najwa')), findsOneWidget);
    expect(find.text(isolate('Chalbi')), findsOneWidget);
  });

  Future<FakePeopleRepository> pumpServe(
    WidgetTester tester,
    AppFailure failure,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final repo = FakePeopleRepository([person(105)])..nextConfirmFailure = failure;
    await tester.pumpWidget(localizedApp(
      _afterSignIn(const PersonDetailsPage(personId: 105)),
      overrides: testOverrides(repo),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.confirmMeal));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('already collected with a time says when', (tester) async {
    final t = DateTime(2025, 3, 5, 18, 10);
    await pumpServe(tester, MealAlreadyTakenFailure(takenAt: t));
    expect(find.text(en.alreadyCollectedAt(ltr(formatTime(t)))), findsOneWidget);
  });

  testWidgets('already collected without a time says so plainly', (tester) async {
    await pumpServe(tester, const MealAlreadyTakenFailure());
    expect(find.text(en.alreadyCollected), findsOneWidget);
  });

  testWidgets('a network failure shows the localized message', (tester) async {
    await pumpServe(tester, const NetworkFailure());
    expect(find.text(failureText(en, const NetworkFailure())), findsOneWidget);
  });

  testWidgets('a double tap on Confirm sends one request', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final repo = FakePeopleRepository([person(107)])..confirmGate = Completer<void>();
    await tester.pumpWidget(localizedApp(
      _afterSignIn(const PersonDetailsPage(personId: 107)),
      overrides: testOverrides(repo),
    ));
    await tester.pumpAndSettle();
    // Both taps land before the first one has rebuilt the button.
    await tester.tap(find.text(en.confirmMeal));
    await tester.tap(find.text(en.confirmMeal), warnIfMissed: false);
    repo.confirmGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.confirmCalls, 1);
    expect(find.text(en.mealConfirmed), findsOneWidget);
  });

  testWidgets('phone and CIN stay left-to-right', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = person(106);
    final withContact = FastingPerson(
      id: base.id,
      firstName: base.firstName,
      lastName: base.lastName,
      cin: '09876543',
      phone: '+216 20 123 456',
      singleMeal: base.singleMeal,
      familyMeal: base.familyMeal,
      lastTakenMeal: base.lastTakenMeal,
      region: testRegion,
    );
    final repo = FakePeopleRepository([withContact]);
    await tester.pumpWidget(localizedApp(
      _afterSignIn(const PersonDetailsPage(personId: 106)),
      overrides: testOverrides(repo),
    ));
    await tester.pumpAndSettle();
    expect(find.text(ltr('+216 20 123 456')), findsOneWidget);
    expect(find.text(ltr('09876543')), findsOneWidget);
    expect(ltr('+216 20 123 456').startsWith('\u2066'), isTrue);
  });

  for (final locale in [const Locale('ar'), const Locale('fr')]) {
    testWidgets('long names lay out in ${locale.languageCode} at 360 px, 1.3x text', (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final repo = FakePeopleRepository([
        person(104, first: 'Mohamed Ali', last: 'Ben Abdelkader Trabelsi'),
      ]);
      await tester.pumpWidget(localizedApp(
        _afterSignIn(const PersonDetailsPage(personId: 104)),
        locale: locale,
        overrides: testOverrides(repo),
      ));
      await tester.pumpAndSettle();
      final strings = lookupAppLocalizations(locale);
      expect(find.text(isolate('Mohamed Ali')), findsOneWidget);
      expect(find.text(strings.confirmMeal), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
