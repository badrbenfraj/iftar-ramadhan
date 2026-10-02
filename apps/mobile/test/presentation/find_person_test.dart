import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iftar_mobile/core/utils/formatters.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/scan/presentation/find_person_page.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  late int? picked;

  GoRouter router() => GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async => picked = await context.push<int>('/find'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(path: '/find', builder: (_, _) => const FindPersonPage()),
    ],
  );

  final repo = FakePeopleRepository([
    person(201, first: 'Hédi', last: 'Jlassi'),
    person(58, first: 'Fatma', last: 'Ben Ali'),
  ]);

  setUp(() => picked = null);

  Future<void> open(WidgetTester tester, {GoRouter? r, FakePeopleRepository? people}) async {
    await tester.pumpWidget(
      localizedRouterApp(r ?? router(), overrides: testOverrides(people ?? repo)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('finds by name ignoring case and accents', (tester) async {
    await open(tester);
    expect(find.text(en.findMinChars), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  HEDI ');
    await tester.pumpAndSettle();
    await tester.tap(find.text(isolate('Hédi Jlassi')));
    await tester.pumpAndSettle();
    expect(picked, 201);
  });

  testWidgets('a card number not on the phone can still be looked up', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '777');
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.findLookUpId(777)));
    await tester.pumpAndSettle();
    expect(picked, 777);
  });

  testWidgets('Arabic-Indic digits look up the card too', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), '٧٧٧');
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.findLookUpId(777)));
    await tester.pumpAndSettle();
    expect(picked, 777);
  });

  testWidgets('shows only the last CIN digits, never the full CIN', (tester) async {
    final withCin = FakePeopleRepository([
      const FastingPerson(
        id: 9,
        firstName: 'Salem',
        lastName: 'Trabelsi',
        singleMeal: 1,
        familyMeal: 0,
        cin: '09876543',
      ),
    ]);
    await open(tester, people: withCin);
    await tester.enterText(find.byType(TextField), 'salem');
    await tester.pumpAndSettle();
    expect(find.text(isolate('Salem Trabelsi')), findsOneWidget);
    expect(find.textContaining('09876543', findRichText: true), findsNothing);
    expect(find.textContaining('543', findRichText: true), findsOneWidget);
  });

  testWidgets('result rows announce the name and status', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    await tester.enterText(find.byType(TextField), 'fatma');
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('Fatma Ben Ali.*${RegExp.escape(en.notServedTooltip)}')),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final locale in [const Locale('ar'), const Locale('fr')]) {
    testWidgets('long names lay out at 360x760, text 1.3, ${locale.languageCode}', (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const longName = 'عبد الرحمن بن محمد الصادق الجلاصي الحامدي';
      final longRepo = FakePeopleRepository([
        person(1, first: longName, last: 'Ben Abdelkarim Al-Jlassi El Hamdi'),
      ]);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        localizedRouterApp(router(), overrides: testOverrides(longRepo), locale: locale),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ben');
      await tester.pumpAndSettle();
      expect(
        find.text(isolate('$longName Ben Abdelkarim Al-Jlassi El Hamdi')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
