import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iftar_mobile/core/utils/formatters.dart';
import 'package:iftar_mobile/core/widgets/brand.dart';
import 'package:iftar_mobile/features/scan/presentation/session_summary_page.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  const summary = SessionSummary(served: 3, singleMeals: 2, familyMeals: 1);

  test('portions count a family meal as four', () {
    expect(summary.portions, 6);
  });

  testWidgets('shows what the volunteer gave tonight and a blessing', (tester) async {
    await tester.pumpWidget(localizedApp(
      const SessionSummaryPage(summary: summary),
      overrides: testOverrides(FakePeopleRepository([])),
    ));
    expect(find.text(ltr('3')), findsOneWidget);
    expect(find.text(en.summaryServedByYou), findsOneWidget);
    expect(find.text(en.summaryDetail(1, 2, 6)), findsOneWidget);
    expect(find.text(blessingText), findsOneWidget);
    expect(find.text(en.backToPeople), findsOneWidget);
    expect(find.text(en.keepScanning), findsOneWidget);
  });

  for (final locale in [const Locale('ar'), const Locale('fr')]) {
    testWidgets('lays out at 360x760, text 1.3, ${locale.languageCode}', (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(localizedApp(
        const SessionSummaryPage(summary: summary),
        overrides: testOverrides(FakePeopleRepository([])),
        locale: locale,
      ));
      expect(find.text(blessingText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pushing /summary with no extra redirects to /people', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('home'))),
        GoRoute(
          path: '/summary',
          redirect: (context, state) => state.extra is SessionSummary ? null : '/people',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(path: '/people', builder: (context, state) => const Scaffold(body: Text('people'))),
      ],
    );
    await tester.pumpWidget(localizedRouterApp(router, overrides: testOverrides(FakePeopleRepository([]))));
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    router.go('/summary');
    await tester.pumpAndSettle();
    expect(find.text('people'), findsOneWidget);
  });

  testWidgets('pushing /summary with wrong-type extra redirects to /people', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('home'))),
        GoRoute(
          path: '/summary',
          redirect: (context, state) => state.extra is SessionSummary ? null : '/people',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(path: '/people', builder: (context, state) => const Scaffold(body: Text('people'))),
      ],
    );
    await tester.pumpWidget(localizedRouterApp(router, overrides: testOverrides(FakePeopleRepository([]))));
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
    router.go('/summary', extra: 'not a summary');
    await tester.pumpAndSettle();
    expect(find.text('people'), findsOneWidget);
  });

  testWidgets('big number and label read as one phrase to screen reader', (tester) async {
    await tester.pumpWidget(localizedApp(
      const SessionSummaryPage(summary: summary),
      overrides: testOverrides(FakePeopleRepository([])),
    ));
    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(RegExp('3.*${RegExp.escape(en.summaryServedByYou)}')),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final textScale in [1.3, 2.0]) {
    for (final counts in [
      (served: 214, single: 400, family: 150),
      (served: 0, single: 0, family: 0),
    ]) {
      for (final locale in [const Locale('en'), const Locale('fr'), const Locale('ar')]) {
        testWidgets(
          'lays out at 360x760, text $textScale, ${locale.languageCode}, ${counts.served} served',
          (tester) async {
            tester.view.physicalSize = const Size(360, 760);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            tester.platformDispatcher.textScaleFactorTestValue = textScale.toDouble();
            addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
            final testSummary = SessionSummary(
              served: counts.served,
              singleMeals: counts.single,
              familyMeals: counts.family,
            );
            await tester.pumpWidget(localizedApp(
              SessionSummaryPage(summary: testSummary),
              overrides: testOverrides(FakePeopleRepository([])),
              locale: locale,
            ));
            expect(find.text(ltr('${counts.served}')), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
