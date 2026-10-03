import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:iftar_mobile/core/router/app_router.dart';
import 'package:iftar_mobile/core/settings/settings_controller.dart';
import 'package:iftar_mobile/core/settings/settings_storage.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_page.dart';
import 'package:iftar_mobile/features/scan/presentation/session_summary_page.dart';
import 'package:iftar_mobile/l10n/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

/// A healthy camera whose detections the test drives by hand.
class _FakeCamera extends MobileScannerController {
  _FakeCamera() : super(autoStart: false);

  final _codes = StreamController<BarcodeCapture>.broadcast();

  @override
  Stream<BarcodeCapture> get barcodes => _codes.stream;

  @override
  Future<void> dispose() async {
    await _codes.close();
    await super.dispose();
  }
}

const _summary = SessionSummary(served: 3, singleMeals: 2, familyMeals: 1);

void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    // The scanner plugin has no host in tests; every call answers at once.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
          (_) async => null,
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
          null,
        ),
  );

  group('session summary, real router', () {
    late ProviderContainer container;

    Future<GoRouter> boot(WidgetTester tester, {bool summary = true}) async {
      container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          ...testOverrides(FakePeopleRepository([person(1)])),
          settingsStorageProvider.overrideWithValue(MemorySettingsStorage()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final router = container.read(routerProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/people');
      if (!summary) return router;
      // As reached from the scanner's Close: the summary on top of /people.
      unawaited(router.push('/summary', extra: _summary));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/summary');
      return router;
    }

    testWidgets('Keep scanning opens the scanner with /people still under it', (tester) async {
      final router = await boot(tester);
      await tester.tap(find.text(en.keepScanning));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/scan');
      expect(find.byType(ScanPage), findsOneWidget);
      expect(router.canPop(), isTrue);

      // Android back from the scanner lands on the list, not out of the app.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/people');
    });

    testWidgets('the real registration form opens over the scanner and backs out to it', (tester) async {
      final router = await boot(tester, summary: false);
      unawaited(router.push('/scan'));
      await tester.pumpAndSettle();
      await container.read(scanControllerProvider.notifier).onDetected('999');
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text(en.registerThisCard));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(router.state.uri.path, '/register-card');
      expect(find.text(en.addTitle), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '999'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/scan');
      expect(find.byType(ScanPage), findsOneWidget);
    });

    testWidgets('saving the registration returns to the scanner, not the list', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final router = await boot(tester, summary: false);
      unawaited(router.push('/scan'));
      await tester.pumpAndSettle();
      await container.read(scanControllerProvider.notifier).onDetected('999');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(en.registerThisCard));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget, reason: 'a way back from the pushed form');

      Finder input(String label) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(input(en.firstName), 'Nour');
      await tester.enterText(input(en.lastName), 'Saidi');
      await tester.dragUntilVisible(
        find.text(en.saveAndHandOver),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.saveAndHandOver));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/scan');
      expect(find.byType(ScanPage), findsOneWidget);
    });

    testWidgets('Back to people lands on /people', (tester) async {
      final router = await boot(tester);
      await tester.tap(find.text(en.backToPeople));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/people');
      expect(find.byType(SessionSummaryPage), findsNothing);
    });
  });

  group('Register this card', () {
    late FakePeopleRepository repo;

    // '/' is the list, '/register-card' a stand-in for the registration form.
    GoRouter router(_FakeCamera camera) => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('people'))),
        GoRoute(path: '/scan', builder: (_, _) => ScanPage(camera: camera)),
        GoRoute(
          path: '/register-card',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: context.pop,
              child: Text('form ${state.uri.queryParameters['id']}'),
            ),
          ),
        ),
        GoRoute(path: '/summary', builder: (_, _) => const Scaffold(body: Text('summary stub'))),
      ],
    );

    setUp(() => repo = FakePeopleRepository([person(101)]));

    Future<ProviderContainer> openScanner(WidgetTester tester, GoRouter r) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(localizedRouterApp(r, overrides: testOverrides(repo)));
      unawaited(r.push('/scan'));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(ScanPage)));
    }

    testWidgets('keeps the session: back from the form shows the same count and Close still summarizes', (tester) async {
      final r = router(_FakeCamera());
      final container = await openScanner(tester, r);
      final scan = container.read(scanControllerProvider.notifier);
      await scan.onDetected('101');
      await scan.confirm();
      await tester.pump(const Duration(seconds: 2)); // confirmed hold ends
      expect(container.read(scanControllerProvider).servedCount, 1);

      await scan.onDetected('999'); // nobody has this card
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(scanControllerProvider).status, isA<ScanNotFound>());

      await tester.tap(find.text(en.registerThisCard));
      await tester.pumpAndSettle();
      expect(find.text('form 999'), findsOneWidget);

      repo.people[999] = person(999); // registered on the form
      await tester.tap(find.text('form 999')); // back from the form
      await tester.pumpAndSettle();
      expect(find.byType(ScanPage), findsOneWidget);
      expect(container.read(scanControllerProvider).servedCount, 1);
      // The scanner looks the card up again and now knows the person.
      final status = container.read(scanControllerProvider).status;
      expect(status, isA<ScanReady>());
      expect((status as ScanReady).person.id, 999);

      await tester.tap(find.byTooltip(en.closeScanner));
      await tester.pumpAndSettle();
      expect(find.text('summary stub'), findsOneWidget);
    });
  });
}
