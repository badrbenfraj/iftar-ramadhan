import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/people/presentation/person_details_page.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

class _OffCamera extends MobileScannerController {
  _OffCamera() : super(autoStart: false) {
    value = const MobileScannerState(
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
      error: MobileScannerException(errorCode: MobileScannerErrorCode.genericError),
    );
  }
}

/// Opening Details from the scan sheet and coming back: the scanner shows
/// what the server now says, without losing a decision still pending.
void main() {
  setUpAll(loadAppFonts);

  late FakePeopleRepository repo;
  late GoRouter router;

  setUp(() => repo = FakePeopleRepository([person(101)]));

  Future<ProviderContainer> openScanner(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    // Haptics go through the platform channel, which has no host in tests.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('home'))),
        GoRoute(path: '/scan', builder: (_, _) => ScanPage(camera: _OffCamera())),
        GoRoute(
          path: '/people/:id',
          builder: (_, state) => PersonDetailsPage(personId: int.parse(state.pathParameters['id']!)),
        ),
      ],
    );
    await tester.pumpWidget(localizedRouterApp(router, overrides: testOverrides(repo)));
    unawaited(router.push('/scan'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(ScanPage)));
    await container.read(authControllerProvider.future);
    return container;
  }

  Future<void> backFromDetails(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle(const Duration(milliseconds: 200), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
  }

  testWidgets('a meal confirmed on Details shows as already served back on the scanner', (tester) async {
    final container = await openScanner(tester);
    await container.read(scanControllerProvider.notifier).onDetected('101');
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(scanControllerProvider).status, isA<ScanReady>());

    await tester.tap(find.text(en.details));
    await tester.pumpAndSettle();
    expect(find.byType(PersonDetailsPage), findsOneWidget);
    await tester.tap(find.text(en.confirmMeal));
    await tester.pumpAndSettle();
    expect(repo.confirmCalls, 1);

    await backFromDetails(tester);
    expect(find.byType(ScanPage), findsOneWidget);
    final state = container.read(scanControllerProvider);
    expect(state.status, isA<ScanAlreadyTaken>());
    expect(state.servedCount, 0, reason: 'not served from the scanner');
    expect(repo.confirmCalls, 1, reason: 'the scanner never confirms a second time');
  });

  testWidgets('looking at Details and coming back keeps the pending contact edits', (tester) async {
    final container = await openScanner(tester);
    final scan = container.read(scanControllerProvider.notifier);
    await scan.onDetected('101');
    scan.editContact(phone: '22123456', comment: 'diabetic');
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(en.details));
    await tester.pumpAndSettle();
    await backFromDetails(tester);

    final status = container.read(scanControllerProvider).status;
    expect(status, isA<ScanReady>());
    expect((status as ScanReady).phone, '22123456');
    expect(status.comment, 'diabetic');
  });
}
