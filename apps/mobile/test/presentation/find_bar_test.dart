import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_result_panel.dart';

import '../support/app_harness.dart';
import '../support/fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  // Idle shows only the camera: people without a card are served from the
  // people list, outside the scanner (user decision, 2026-10-02).
  testWidgets('idle scanner shows no sheet over the camera', (tester) async {
    tester.view.physicalSize = const Size(360, 760);
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

    expect(find.text(en.findNoCard), findsNothing);
    expect(tester.getSize(find.byType(ScanResultPanel)).height, 0);
    expect(tester.takeException(), isNull);
  });
}
