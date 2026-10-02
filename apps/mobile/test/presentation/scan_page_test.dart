import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iftar_mobile/core/utils/formatters.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_page.dart';
import 'package:iftar_mobile/l10n/app_localizations.dart';
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

/// A healthy camera whose detections the test drives by hand.
class _FakeCamera extends MobileScannerController {
  _FakeCamera() : super(autoStart: false);

  final _codes = StreamController<BarcodeCapture>.broadcast();

  @override
  Stream<BarcodeCapture> get barcodes => _codes.stream;

  void emit(String raw) => _codes.add(BarcodeCapture(barcodes: [Barcode(rawValue: raw)]));

  @override
  Future<void> dispose() async {
    await _codes.close();
    await super.dispose();
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

  Future<ProviderContainer> open(
    WidgetTester tester, {
    MobileScannerController? camera,
    Locale locale = const Locale('en'),
    Size size = const Size(1080, 2280),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      localizedRouterApp(router(camera ?? _FakeCamera()), overrides: testOverrides(repo), locale: locale),
    );
    await tester.pump(const Duration(milliseconds: 300));
    // MobileScanner subscribes to the camera's stream after an async start.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
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

  testWidgets('backstop: a pending person is not replaced by a late find result', (tester) async {
    final container = await open(tester);
    await tester.tap(find.text(en.findNoCard));
    await tester.pumpAndSettle();
    // A pending decision appears meanwhile (set directly, bypassing the page).
    await container.read(scanControllerProvider.notifier).onDetected('101');
    await tester.tap(find.text('pick 102'));
    await tester.pumpAndSettle();
    final status = container.read(scanControllerProvider).status;
    expect(status, isA<ScanReady>());
    expect((status as ScanReady).person.id, 101);
    expect(status.noCard, isFalse);
  });

  testWidgets('a card the camera reads while Find is open does not replace the pick', (tester) async {
    final cam = _FakeCamera();
    final container = await open(tester, camera: cam);
    await tester.tap(find.text(en.findNoCard));
    await tester.pumpAndSettle();
    cam.emit('101'); // the camera keeps running under the Find page
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('pick 102'));
    await tester.pumpAndSettle();
    final status = container.read(scanControllerProvider).status;
    expect(status, isA<ScanReady>());
    expect((status as ScanReady).person.id, 102);
    expect(status.noCard, isTrue);
  });

  testWidgets('a detection on the scan screen itself is still processed', (tester) async {
    final cam = _FakeCamera();
    final container = await open(tester, camera: cam);
    cam.emit('101');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect((container.read(scanControllerProvider).status as ScanReady).person.id, 101);
  });

  group('selection haptic', () {
    final calls = <String>[];
    setUp(() {
      calls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') calls.add('${call.arguments}');
          return null;
        },
      );
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    testWidgets('editing the contact does not buzz again', (tester) async {
      final container = await open(tester, camera: _BrokenCamera(MobileScannerErrorCode.genericError));
      final ctl = container.read(scanControllerProvider.notifier);
      await ctl.onDetected('101');
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls.where((c) => c.contains('selectionClick')).length, 1);
      ctl.editContact(phone: '22123456', comment: 'diabetic');
      await tester.pump(const Duration(milliseconds: 300));
      expect(calls.where((c) => c.contains('selectionClick')).length, 1);
    });
  });

  testWidgets('Android back after serving shows the summary', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('home'))),
        GoRoute(
          path: '/scan',
          builder: (_, _) => ScanPage(camera: _BrokenCamera(MobileScannerErrorCode.genericError)),
        ),
        GoRoute(path: '/summary', builder: (_, _) => const Scaffold(body: Text('summary stub'))),
      ],
    );
    await tester.pumpWidget(localizedRouterApp(router, overrides: testOverrides(repo)));
    unawaited(router.push('/scan'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(ScanPage)));
    await container.read(scanControllerProvider.notifier).onDetected('101');
    await container.read(scanControllerProvider.notifier).confirm();
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(scanControllerProvider).servedCount, 1);

    // The router's back-button dispatcher listens on the binding.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle(const Duration(milliseconds: 200), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('summary stub'), findsOneWidget);
  });

  testWidgets('320×568 at 2.0x: the sheet scrolls as one unit and Confirm is reachable', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final long = FastingPerson(
      id: 9,
      firstName: 'Mohamed Ali Ben Abdelkader',
      lastName: 'Trabelsi El Kairouani',
      cin: '08123812',
      phone: '+216 98 123 456',
      comment: 'Lives near the mosque, comes with two children',
      singleMeal: 2,
      familyMeal: 1,
      lastTakenMeal: testNow.subtract(const Duration(days: 1)),
      region: testRegion,
    );
    repo = FakePeopleRepository([long]);
    final container = await open(
      tester,
      size: const Size(960, 1704), // 320×568 at 3x
    );
    await container.read(authControllerProvider.future);
    await container.read(scanControllerProvider.notifier).pickWithoutCard(9);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    final confirm = find.ancestor(of: find.text(en.confirmHandOver), matching: find.byType(FilledButton));
    await tester.ensureVisible(confirm);
    await tester.pump(const Duration(milliseconds: 300));
    const screen = Rect.fromLTWH(0, 0, 320, 568);
    final r = tester.getRect(confirm);
    expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight - const Offset(0.01, 0.01)), isTrue, reason: '$r');
    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.confirmCalls, 1);
    await tester.pump(const Duration(seconds: 2));
  });

  for (final lc in ['en', 'ar']) {
    testWidgets('2.0x text, no-card flow: name and Confirm are on screen together and Confirm works ($lc)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final long = FastingPerson(
        id: 9,
        firstName: 'Mohamed Ali Ben Abdelkader',
        lastName: 'Trabelsi El Kairouani',
        cin: '08123812',
        phone: '+216 98 123 456',
        comment: 'Lives near the mosque, comes with two children',
        singleMeal: 2,
        familyMeal: 1,
        lastTakenMeal: testNow.subtract(const Duration(days: 1)),
        region: testRegion,
      );
      repo = FakePeopleRepository([long]);
      final container = await open(tester, camera: _BrokenCamera(MobileScannerErrorCode.genericError), locale: Locale(lc));
      await container.read(authControllerProvider.future);
      await container.read(scanControllerProvider.notifier).pickWithoutCard(9);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(scanControllerProvider).status, isA<ScanReady>());

      final l = lookupAppLocalizations(Locale(lc));
      const screen = Rect.fromLTWH(0, 0, 360, 760);
      bool inside(Rect r) => screen.contains(r.topLeft) && screen.contains(r.bottomRight - const Offset(0.01, 0.01));
      final confirm = find.ancestor(of: find.text(l.confirmHandOver), matching: find.byType(FilledButton));
      final name = find.textContaining('Mohamed Ali');
      expect(inside(tester.getRect(confirm)), isTrue, reason: 'Confirm ${tester.getRect(confirm)}');
      expect(inside(tester.getRect(name)), isTrue, reason: 'name ${tester.getRect(name)}');
      expect(find.text(l.noCardCheck(ltr('812'))), findsOneWidget);
      expect(inside(tester.getRect(find.text(l.noCardCheck(ltr('812'))))), isTrue, reason: 'CIN prompt on screen');

      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.confirmCalls, 1);
      await tester.pump(const Duration(seconds: 2)); // confirmed hold ends
    });
  }
}
