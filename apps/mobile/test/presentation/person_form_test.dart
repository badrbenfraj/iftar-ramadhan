import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/utils/formatters.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/people/presentation/person_form_page.dart';
import 'package:iftar_mobile/l10n/app_localizations.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  late FakePeopleRepository repo;

  setUp(() {
    repo = FakePeopleRepository([
      const FastingPerson(
        id: 142,
        firstName: 'Fatma',
        lastName: 'Trabelsi',
        cin: '08123812',
        singleMeal: 0,
        familyMeal: 1,
      ),
    ]);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(
      AddPersonPage(scanCardId: (_) async => 215),
      overrides: testOverrides(repo),
    ));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(Column),
  ).first;

  Finder input(String label) =>
      find.descendant(of: field(label), matching: find.byType(TextFormField));

  testWidgets('scanning the card fills its ID', (tester) async {
    await pump(tester);
    await tester.tap(find.text(en.scanCard));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '215'), findsOneWidget);
    expect(find.text(en.cardRead(215)), findsOneWidget);
  });

  testWidgets('an already-registered CIN is flagged before saving', (tester) async {
    await pump(tester);
    await tester.enterText(input(en.cinLabel), '08123812');
    await tester.pumpAndSettle();
    expect(find.text(en.duplicateCin(isolate('Fatma Trabelsi'), 142)), findsOneWidget);
    expect(find.text(en.openExistingRecord), findsOneWidget);
    // Not colour alone: there is an icon too.
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('a CIN typed with Arabic-Indic digits is normalised and flagged', (tester) async {
    await pump(tester);
    await tester.enterText(input(en.cinLabel), '٠٨١٢٣٨١٢');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, '08123812'), findsOneWidget);
    expect(find.text(en.duplicateCin(isolate('Fatma Trabelsi'), 142)), findsOneWidget);
  });

  testWidgets('steppers update the hand-over line', (tester) async {
    await pump(tester);
    expect(find.text(en.handsOverEachEvening(1)), findsOneWidget); // default: 1 single
    final familyIncrease = find.descendant(
      of: find.ancestor(of: find.text(en.familyMeal), matching: find.byType(Row)).first,
      matching: find.byTooltip(en.increase),
    );
    await tester.tap(familyIncrease);
    await tester.pump();
    expect(find.text(en.handsOverEachEvening(5)), findsOneWidget);
  });

  testWidgets('save and add another stays on a cleared form', (tester) async {
    await pump(tester);
    await tester.tap(find.text(en.scanCard));
    await tester.pumpAndSettle();
    await tester.enterText(input(en.firstName), 'Nour');
    await tester.enterText(input(en.lastName), 'Saidi');
    await tester.dragUntilVisible(find.text(en.saveAndAddAnother), find.byType(ListView), const Offset(0, -200));
    await tester.ensureVisible(find.text(en.saveAndAddAnother)); // built is not on-screen
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.saveAndAddAnother));
    await tester.pumpAndSettle();

    expect(repo.people[215]?.fullName, 'Nour Saidi');
    expect(repo.people[215]?.isMealTakenToday(testNow), isTrue); // "Here now" defaults on
    expect(find.text(en.personSavedHandOver(isolate('Nour Saidi'), 1)), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Nour'), findsNothing);
    expect(find.widgetWithText(TextFormField, '215'), findsNothing);
  });

  for (final inset in [34.0, 0.0]) {
    testWidgets('the save buttons clear the tab bar and a $inset px inset', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = FakeViewPadding(bottom: inset);
      tester.view.padding = FakeViewPadding(bottom: inset);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(localizedApp(
        AddPersonPage(scanCardId: (_) async => 215),
        overrides: testOverrides(repo),
      ));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      final limit = 800 - 72 - inset - 40 + 1;
      expect(tester.getBottomLeft(find.byType(FilledButton)).dy, lessThanOrEqualTo(limit));
      expect(tester.getBottomLeft(find.widgetWithText(TextButton, en.saveAndAddAnother)).dy, lessThanOrEqualTo(limit));
    });
  }

  for (final locale in ['ar', 'fr']) {
    testWidgets('the form lays out at 360 px and 1.3x text in $locale', (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final l = lookupAppLocalizations(Locale(locale));
      await tester.pumpWidget(localizedApp(
        AddPersonPage(scanCardId: (_) async => 215),
        overrides: testOverrides(repo),
        locale: Locale(locale),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(input(l.cinLabel), '08123812');
      await tester.pumpAndSettle();
      expect(find.text(l.openExistingRecord), findsOneWidget);
      await tester.dragUntilVisible(find.text(l.saveAndHandOver), find.byType(ListView), const Offset(0, -200));
      expect(find.text(l.saveAndHandOver), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the edit form shows the person and keeps the ID fixed', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(
      Scaffold(body: PersonForm(person: repo.people[142])),
      overrides: testOverrides(repo),
    ));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Fatma'), findsOneWidget);
    expect(find.text(en.scanCard), findsNothing);
    // Editing a person never flags their own CIN as a duplicate.
    expect(find.text(en.openExistingRecord), findsNothing);
    await tester.dragUntilVisible(find.text(en.deletePerson), find.byType(ListView), const Offset(0, -200));
    expect(find.text(en.updatePerson), findsOneWidget);
  });
}
