import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/people/presentation/people_list_page.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Waiting and Served filters narrow the list', (tester) async {
    final repo = FakePeopleRepository([
      person(1, first: 'Najwa', last: 'Chalbi'),
      person(2, first: 'Aziza', last: 'Ouerghi', takenToday: true),
    ]);
    await tester.pumpWidget(localizedApp(const PeopleListPage(), overrides: testOverrides(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.text(en.filterWaiting));
    await tester.pumpAndSettle();
    expect(find.text('Najwa Chalbi'), findsOneWidget);
    expect(find.text('Aziza Ouerghi'), findsNothing);

    await tester.tap(find.text(en.filterServed));
    await tester.pumpAndSettle();
    expect(find.text('Najwa Chalbi'), findsNothing);
    expect(find.text('Aziza Ouerghi'), findsOneWidget);

    await tester.tap(find.text(en.filterAll));
    await tester.pumpAndSettle();
  });

  testWidgets('the selected filter is announced as selected', (tester) async {
    final repo = FakePeopleRepository([person(1)]);
    await tester.pumpWidget(localizedApp(const PeopleListPage(), overrides: testOverrides(repo)));
    await tester.pumpAndSettle();

    bool? selectedOf(String label) {
      final chip = find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.selected != null),
      );
      return tester.widget<Semantics>(chip.first).properties.selected;
    }

    expect(selectedOf(en.filterAll), isTrue);
    expect(selectedOf(en.filterWaiting), isFalse);
    await tester.tap(find.text(en.filterWaiting));
    await tester.pumpAndSettle();
    expect(selectedOf(en.filterWaiting), isTrue);
    expect(selectedOf(en.filterAll), isFalse);
  });

  testWidgets('filter chips are at least 48 px tall', (tester) async {
    final repo = FakePeopleRepository([person(1)]);
    await tester.pumpWidget(localizedApp(const PeopleListPage(), overrides: testOverrides(repo)));
    await tester.pumpAndSettle();
    for (final label in [en.filterAll, en.filterWaiting, en.filterServed]) {
      final box = find.ancestor(of: find.text(label), matching: find.byType(InkWell));
      expect(tester.getSize(box.first).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('everyone served shows a calm empty state', (tester) async {
    final repo = FakePeopleRepository([person(2, takenToday: true)]);
    await tester.pumpWidget(localizedApp(const PeopleListPage(), overrides: testOverrides(repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.filterWaiting));
    await tester.pumpAndSettle();
    expect(find.text(en.everyoneServed), findsOneWidget);
    await tester.tap(find.text(en.filterAll));
    await tester.pumpAndSettle();
  });

  for (final locale in [const Locale('ar'), const Locale('fr')]) {
    testWidgets('very long names ellipsize in ${locale.languageCode} at 360 px, 1.3x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final repo = FakePeopleRepository([
        person(1, first: 'Mohamed Ali Ben Abdelkader', last: 'Trabelsi'),
        person(2, first: 'Mohamed Ali Ben Abdelkader', last: 'Trabelsi', takenToday: true),
      ]);
      await tester.pumpWidget(
        localizedApp(const PeopleListPage(), locale: locale, overrides: testOverrides(repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mohamed Ali Ben Abdelkader Trabelsi'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the last row clears the tab bar and the gesture inset', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);
    final repo = FakePeopleRepository([
      for (var i = 1; i <= 14; i++) person(i, first: 'Person', last: 'Number$i'),
    ]);
    await tester.pumpWidget(localizedApp(const PeopleListPage(), overrides: testOverrides(repo)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    final last = find.ancestor(of: find.text('Person Number14'), matching: find.byType(Card));
    expect(last, findsOneWidget);
    expect(tester.getBottomLeft(last).dy, lessThanOrEqualTo(800 - 72 - 34));
  });
}
