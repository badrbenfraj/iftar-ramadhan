import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
