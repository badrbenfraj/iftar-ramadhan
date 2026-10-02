import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_result_panel.dart';

import '../support/app_harness.dart';
import '../support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  // The scan page gives the panel all the space below the top bar
  // (Expanded → Align(bottom) → Column(min) → Flexible). The idle find bar
  // must stay a compact bar at the bottom instead of filling that space.
  for (final size in const [Size(360, 760), Size(1280, 900)]) {
    testWidgets('idle find bar stays compact at ${size.width.toInt()}×${size.height.toInt()}',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(localizedApp(
        Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 120),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: ScanResultPanel(
                          status: const ScanIdle(),
                          onFindWithoutCard: () {},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final bar = tester.getRect(find.byType(ScanResultPanel));
      expect(bar.height, lessThan(140), reason: 'find bar height ${bar.height}');
      expect(bar.bottom, size.height, reason: 'anchored to the bottom');
      expect(find.text(en.findNoCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
