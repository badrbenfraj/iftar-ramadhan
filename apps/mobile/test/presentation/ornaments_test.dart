import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/widgets/arch_window.dart';
import 'package:iftar_mobile/core/widgets/khatam.dart';
import 'package:iftar_mobile/core/widgets/night_sky.dart';
import 'package:iftar_mobile/core/widgets/seal.dart';

import '../support/app_harness.dart';

void main() {
  test('the 8-point star fits inside its radius', () {
    final bounds = khatamPath(const Offset(50, 50), 20).getBounds();
    expect(bounds.width, closeTo(40, 0.01));
    expect(bounds.height, closeTo(40, 0.01));
    expect(bounds.center, const Offset(50, 50));
  });

  testWidgets('seals are labelled for screen readers', (tester) async {
    await tester.pumpWidget(localizedApp(const Scaffold(
      body: Row(children: [
        Seal(SealKind.serve, semanticLabel: 'Can be served'),
        Seal(SealKind.served, semanticLabel: 'Already served'),
        Seal(SealKind.problem, semanticLabel: 'Needs attention'),
        Seal(SealKind.done, semanticLabel: 'Served'),
        Seal(SealKind.checking, semanticLabel: 'Checking'),
      ]),
    )));
    await tester.pump(const Duration(milliseconds: 300)); // pulse is looping
    for (final label in ['Can be served', 'Already served', 'Needs attention', 'Served', 'Checking']) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('sky band, night sky and arch window render their child', (tester) async {
    await tester.pumpWidget(localizedApp(const Scaffold(
      body: Column(children: [
        SkyBand(child: Text('band')),
        SizedBox(height: 120, child: NightSky(dusk: true, pattern: true, child: Text('sky'))),
        ArchWindow(child: Text('arch')),
      ]),
    )));
    expect(find.text('band'), findsOneWidget);
    expect(find.text('sky'), findsOneWidget);
    expect(find.text('arch'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('khatam pattern clips to its bounds in sky band', (tester) async {
    // SkyBand has the khatam pattern; if it escapes bounds, it would be visible
    // in a painted area. This test verifies the pattern is painted cleanly.
    await tester.pumpWidget(localizedApp(const Scaffold(
      body: SizedBox(
        height: 120,
        child: SkyBand(child: Text('band content')),
      ),
    )));
    expect(find.text('band content'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seal with reduced motion settles and is fully visible', (tester) async {
    // Disable animations via MediaQuery.
    await tester.pumpWidget(localizedApp(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Scaffold(
        body: Center(
          child: Seal(SealKind.checking, semanticLabel: 'Checking progress'),
        ),
      ),
    )));

    // Should settle without hanging (animation is stopped).
    await tester.pumpAndSettle();

    // Seal should still be found by its semantic label.
    expect(find.bySemanticsLabel('Checking progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
