import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/utils/formatters.dart';
import 'package:iftar_mobile/core/widgets/state_views.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/people/presentation/people_controller.dart';
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

  testWidgets('keeps its label once text is typed', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'hedi');
    await tester.pumpAndSettle();
    expect(find.text(en.findSearchHint), findsWidgets);
  });

  testWidgets('shows a spinner, not "no match", while the list loads', (tester) async {
    final gate = Completer<List<FastingPerson>>();
    await tester.pumpWidget(
      localizedRouterApp(
        router(),
        overrides: [
          ...testOverrides(repo),
          peopleListProvider.overrideWith(() => _StubList(gate.future)),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField), 'hedi');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LoadingView), findsOneWidget);
    expect(find.text(en.noMatch(isolate('hedi'))), findsNothing);
  });

  testWidgets('a failed list shows the error with retry', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      localizedRouterApp(
        router(),
        overrides: [
          ...testOverrides(repo),
          peopleListProvider.overrideWith(() => _StubList(null, onBuild: () => calls++)),
        ],
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hedi');
    await tester.pumpAndSettle();
    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text(en.noMatch(isolate('hedi'))), findsNothing);
    final before = calls;
    await tester.tap(find.text(en.tryAgain));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(before));
  });

  testWidgets('the header back button pops null', (tester) async {
    picked = -1;
    await open(tester);
    await tester.tap(find.byTooltip(en.back));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('system back pops null', (tester) async {
    picked = -1;
    await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('tapping a result twice quickly pops once with the ID', (tester) async {
    var pops = 0;
    final r = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await context.push<int>('/find');
                pops++;
              },
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(path: '/find', builder: (_, _) => const FindPersonPage()),
      ],
    );
    await open(tester, r: r);
    await tester.enterText(find.byType(TextField), 'hedi');
    await tester.pumpAndSettle();
    final row = find.text(isolate('Hédi Jlassi'));
    await tester.tap(row);
    await tester.tap(row, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(picked, 201);
    expect(pops, 1);
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

/// Loads never (when given a future) or fails (when null).
class _StubList extends PeopleListController {
  _StubList(this._pending, {this.onBuild});

  final Future<List<FastingPerson>>? _pending;
  final void Function()? onBuild;

  @override
  Future<List<FastingPerson>> build() {
    onBuild?.call();
    return _pending ?? Future.error(const NetworkFailure());
  }
}
