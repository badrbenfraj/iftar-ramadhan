import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/scan/presentation/card_id_scanner.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('camera denied explains itself and can be closed', (tester) async {
    var closed = false;
    await tester.pumpWidget(localizedApp(
      CardScannerError(denied: true, onClose: () => closed = true),
    ));
    expect(find.text(en.cameraOffTitle), findsOneWidget);
    expect(find.text(en.cameraOffMessage), findsOneWidget);
    await tester.tap(find.byTooltip(en.cancel));
    expect(closed, isTrue);
  });

  testWidgets('any other camera failure uses the unavailable message', (tester) async {
    await tester.pumpWidget(localizedApp(
      CardScannerError(denied: false, onClose: () {}),
    ));
    expect(find.text(en.cameraUnavailableTitle), findsOneWidget);
    expect(find.text(en.cameraUnavailableMessage), findsOneWidget);
  });
}
