import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

/// A camera that never starts and reports [code], as on a phone without
/// camera permission.
class _BrokenCamera extends MobileScannerController {
  _BrokenCamera(MobileScannerErrorCode code) : super(autoStart: false) {
    value = MobileScannerState(
      availableCameras: 0,
      cameraDirection: CameraFacing.back,
      cameraLensType: CameraLensType.any,
      isInitialized: true,
      isStarting: false,
      isRunning: false,
      size: Size.zero,
      torchState: TorchState.unavailable,
      zoomScale: 1,
      deviceOrientation: DeviceOrientation.portraitUp,
      error: MobileScannerException(errorCode: code),
    );
  }
}

void main() {
  setUpAll(loadAppFonts);

  late FakePeopleRepository repo;

  GoRouter router([MobileScannerController? camera]) => GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => ScanPage(camera: camera)),
      GoRoute(
        path: '/find',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.pop(102),
              child: const Text('pick 102'),
            ),
          ),
        ),
      ),
    ],
  );

  setUp(() => repo = FakePeopleRepository([person(101), person(102, first: 'Aziza', last: 'Ouerghi')]));

  Future<ProviderContainer> open(WidgetTester tester, {MobileScannerController? camera}) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedRouterApp(router(camera), overrides: testOverrides(repo)));
    await tester.pump(const Duration(milliseconds: 300));
    return ProviderScope.containerOf(tester.element(find.byType(ScanPage)));
  }

  FilledButton findButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(of: find.text(en.findNoCard), matching: find.byType(FilledButton)),
  );

  const denied =MobileScannerErrorCode.permissionDenied;

  testWidgets('without camera permission the page says so and still offers find', (tester) async {
    await open(tester, camera: _BrokenCamera(denied));
    expect(find.text(en.cameraOffTitle), findsOneWidget);
    expect(find.text(en.cameraOffMessage), findsOneWidget);
  });

  testWidgets('another camera failure is not reported as a permission problem', (tester) async {
    await open(tester, camera: _BrokenCamera(MobileScannerErrorCode.genericError));
    expect(find.text(en.cameraUnavailableTitle), findsOneWidget);
    expect(find.text(en.cameraOffTitle), findsNothing);
  });

  testWidgets('with no camera, finding someone is offered while idle', (tester) async {
    await open(tester, camera: _BrokenCamera(denied));
    expect(findButton(tester).onPressed, isNotNull);
  });

  testWidgets('with no camera, finding someone is disabled while a person is pending', (tester) async {
    final container = await open(tester, camera: _BrokenCamera(denied));
    await container.read(scanControllerProvider.notifier).onDetected('101');
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(scanControllerProvider).status, isA<ScanReady>());
    expect(findButton(tester).onPressed, isNull);
  });

  testWidgets('a card scanned while the find page is open is not replaced by its result', (tester) async {
    final container = await open(tester);
    await tester.tap(find.text(en.findNoCard));
    await tester.pumpAndSettle();
    // A card is read meanwhile and is now awaiting its confirmation.
    await container.read(scanControllerProvider.notifier).onDetected('101');
    await tester.tap(find.text('pick 102'));
    await tester.pumpAndSettle();
    final status = container.read(scanControllerProvider).status;
    expect(status, isA<ScanReady>());
    expect((status as ScanReady).person.id, 101);
    expect(status.noCard, isFalse);
  });
}
