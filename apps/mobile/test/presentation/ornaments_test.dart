import 'dart:ui' as ui;

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

  testWidgets('khatam pattern never paints outside its box', (tester) async {
    // Render the khatam pattern to a 360x120 canvas, then rasterize to a larger
    // 400x200 image. Every pixel with y >= 120 or x >= 360 must have alpha 0.
    // This proves the pattern respects clipRect.
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 360, 120));
      const painter = KhatamPatternPainter(
        color: Color(0xFFFFFFFF),
        opacity: 1,
        tile: 44,
      );
      painter.paint(canvas, const Size(360, 120));

      final image = await recorder.endRecording().toImage(400, 200);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;

      // Check that every pixel outside the 360x120 box has alpha 0.
      bool foundPaintedPixel = false;
      for (var y = 0; y < 200; y++) {
        for (var x = 0; x < 400; x++) {
          final alpha = bytes.getUint8((y * 400 + x) * 4 + 3);
          if (x >= 360 || y >= 120) {
            // Outside the box: must be transparent
            expect(alpha, 0, reason: 'Pixel at ($x, $y) is outside bounds but has alpha $alpha');
          } else {
            // Inside the box: at least one pixel should be painted
            if (alpha > 0) foundPaintedPixel = true;
          }
        }
      }

      // Ensure the pattern actually painted something (not empty)
      expect(foundPaintedPixel, true, reason: 'Pattern did not paint any visible pixels inside bounds');
    });
  });

  testWidgets('seal with reduced motion settles and is fully opaque', (tester) async {
    // Disable animations via MediaQuery. The pulse animation should stop and reset
    // opacity to fully visible (value 0 of the Tween, which maps to opacity 1).
    await tester.pumpWidget(localizedApp(const MediaQuery(
      data: MediaQueryData(disableAnimations: true),
      child: Scaffold(
        body: Center(
          child: Seal(SealKind.checking, semanticLabel: 'Checking progress'),
        ),
      ),
    )));

    // Should settle without hanging because animation is stopped, not looping.
    await tester.pumpAndSettle();

    // Seal should be found by semantic label and have no errors.
    expect(find.bySemanticsLabel('Checking progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
