import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/shell/home_shell.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('the scan button rises only slightly above the bar', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var scanned = false;
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: AppBottomNav(
          currentIndex: 0,
          onSelect: (_) {},
          onScan: () => scanned = true,
        ),
      ),
    ));
    final bar = tester.getRect(find.byType(AppBottomNav));
    final button = tester.getRect(find.byType(ScanButton));
    // Lifted a little for presence, but most of it stays in the bar so it
    // never covers the page's sheets and dialogs.
    expect(button.top, lessThan(bar.top), reason: 'button $button, bar $bar');
    expect(bar.top - button.top, lessThanOrEqualTo(20));
    expect(button.bottom, lessThanOrEqualTo(bar.bottom));
    expect((button.center.dx - bar.center.dx).abs(), lessThan(1), reason: 'centred');
    expect(button.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byType(ScanButton));
    expect(scanned, isTrue);
    expect(tester.takeException(), isNull);
  });

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

  testWidgets('screen readers can activate tabs', (tester) async {
    var selected = -1;
    Widget nav() => localizedApp(
      Scaffold(
        bottomNavigationBar: AppBottomNav(currentIndex: 0, onSelect: (i) => selected = i),
      ),
      locale: const Locale('en'),
    );

    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(nav());

      final statsNode = tester.getSemantics(find.bySemanticsLabel(en.navStats));
      expect(statsNode.label, en.navStats);

      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!
          .performAction(statsNode.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(selected, 2);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('scan button is accessible to screen readers', (tester) async {
    var scanned = false;
    Widget nav() => localizedApp(
      Scaffold(
        floatingActionButton: ScanButton(onPressed: () => scanned = true),
        bottomNavigationBar: const SizedBox.shrink(),
      ),
      locale: const Locale('en'),
    );

    final handle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(nav());

      final scanNode = tester.getSemantics(find.bySemanticsLabel(en.navScan));
      expect(scanNode.label, en.navScan);

      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!
          .performAction(scanNode.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(scanned, isTrue);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('Arabic tab labels have correct letterSpacing', (tester) async {
    Widget nav() => localizedApp(
      Scaffold(
        bottomNavigationBar: AppBottomNav(currentIndex: 0, onSelect: (_) {}),
      ),
      locale: const Locale('ar'),
    );

    await tester.pumpWidget(nav());

    final textWidget = tester.widget<Text>(find.text(ar.navPeople));
    expect(textWidget.style!.letterSpacing, 0);
  });
}
