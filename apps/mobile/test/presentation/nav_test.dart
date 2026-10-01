import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/shell/home_shell.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('tabs are labelled in the UI language and report taps', (tester) async {
    var selected = -1;
    var scanned = false;
    Widget nav(Locale locale) => localizedApp(
      Scaffold(
        floatingActionButton: ScanButton(onPressed: () => scanned = true),
        bottomNavigationBar: AppBottomNav(currentIndex: 0, onSelect: (i) => selected = i),
      ),
      locale: locale,
    );

    await tester.pumpWidget(nav(const Locale('en')));
    for (final label in [en.navPeople, en.navAdd, en.navStats, en.navProfile]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text(en.navStats));
    expect(selected, 2);
    await tester.tap(find.byTooltip(en.navScan));
    expect(scanned, isTrue);

    await tester.pumpWidget(nav(const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.text(ar.navPeople), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
