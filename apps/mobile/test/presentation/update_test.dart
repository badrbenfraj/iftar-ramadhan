import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/config/app_config.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/providers.dart';
import 'package:iftar_mobile/features/update/data/version_repository.dart';
import 'package:iftar_mobile/features/update/domain/app_version_info.dart';
import 'package:iftar_mobile/features/update/presentation/update_controller.dart';
import 'package:iftar_mobile/features/update/presentation/update_views.dart';

import '../support/app_harness.dart';

class FakeVersionRepository implements VersionRepository {
  FakeVersionRepository(this.info);

  AppVersionInfo info;
  AppFailure? failure;
  int calls = 0;

  @override
  Future<AppVersionInfo> fetch() async {
    calls++;
    if (failure case final f?) throw f;
    return info;
  }
}

const _server = 'https://vps-test.vps.ovh.net';

List<Override> overridesFor(
  FakeVersionRepository repo, {
  String installed = '1.4.0',
  List<Uri>? opened,
  DateTime Function()? clock,
}) => [
  versionRepositoryProvider.overrideWithValue(repo),
  installedVersionProvider.overrideWith((_) async => installed),
  appConfigProvider.overrideWithValue(
    const AppConfig(apiUrl: _server, environment: 'test'),
  ),
  urlOpenerProvider.overrideWithValue((uri) async {
    opened?.add(uri);
    return true;
  }),
  if (clock != null) clockProvider.overrideWithValue(clock),
];

/// 1.4.0 installed: optional update. 1.3.0 installed: required.
const _release = AppVersionInfo(latestVersion: '1.5.0', minimumVersion: '1.4.0');

void main() {
  group('UpdateController', () {
    test('optional update when a newer version is published', () async {
      final c = ProviderContainer(overrides: overridesFor(FakeVersionRepository(_release)));
      addTearDown(c.dispose);
      await c.read(updateControllerProvider.notifier).check();
      expect(c.read(updateControllerProvider).status, UpdateStatus.optional);
      expect(c.read(updateControllerProvider).showOptionalPrompt, isTrue);
    });

    test('required update below the minimum version', () async {
      final c = ProviderContainer(
        overrides: overridesFor(FakeVersionRepository(_release), installed: '1.3.0'),
      );
      addTearDown(c.dispose);
      await c.read(updateControllerProvider.notifier).check();
      expect(c.read(updateControllerProvider).status, UpdateStatus.required);
    });

    test('offline at startup: the app carries on as up to date', () async {
      final repo = FakeVersionRepository(_release)..failure = const NetworkFailure();
      final c = ProviderContainer(overrides: overridesFor(repo));
      addTearDown(c.dispose);
      await c.read(updateControllerProvider.notifier).check();
      expect(c.read(updateControllerProvider).status, UpdateStatus.upToDate);
    });

    test('a later failed check keeps a required update required', () async {
      final repo = FakeVersionRepository(_release);
      final c = ProviderContainer(overrides: overridesFor(repo, installed: '1.3.0'));
      addTearDown(c.dispose);
      final controller = c.read(updateControllerProvider.notifier);
      await controller.check();
      repo.failure = const NetworkFailure();
      await controller.check();
      expect(c.read(updateControllerProvider).status, UpdateStatus.required);
    });

    test('"Later" hides the prompt until a different version is published', () async {
      final repo = FakeVersionRepository(_release);
      final c = ProviderContainer(overrides: overridesFor(repo));
      addTearDown(c.dispose);
      final controller = c.read(updateControllerProvider.notifier);
      await controller.check();
      controller.dismissPrompt();
      await controller.check();
      expect(c.read(updateControllerProvider).showOptionalPrompt, isFalse);

      repo.info = const AppVersionInfo(latestVersion: '1.6.0', minimumVersion: '1.4.0');
      await controller.check();
      expect(c.read(updateControllerProvider).showOptionalPrompt, isTrue);
    });

    test('resume re-checks only when the last answer is over an hour old', () async {
      var now = DateTime(2027, 2, 10, 17);
      final repo = FakeVersionRepository(_release);
      final c = ProviderContainer(overrides: overridesFor(repo, clock: () => now));
      addTearDown(c.dispose);
      final controller = c.read(updateControllerProvider.notifier);
      await controller.check();
      now = now.add(const Duration(minutes: 30));
      await controller.checkIfStale();
      expect(repo.calls, 1);
      now = now.add(const Duration(minutes: 31));
      await controller.checkIfStale();
      expect(repo.calls, 2);
    });

    test('opens the /download page of the configured server', () async {
      final opened = <Uri>[];
      final c = ProviderContainer(
        overrides: overridesFor(FakeVersionRepository(_release), opened: opened),
      );
      addTearDown(c.dispose);
      await c.read(updateControllerProvider.notifier).check();
      expect(await c.read(updateControllerProvider.notifier).openDownloadPage(), isTrue);
      expect(opened, [Uri.parse('$_server/download')]);
    });
  });

  group('update screens', () {
    testWidgets('the force-update screen has Update and no way to skip', (tester) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        localizedApp(
          const ForceUpdatePage(),
          overrides: overridesFor(FakeVersionRepository(_release), opened: opened),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.updateRequiredTitle), findsOneWidget);
      expect(find.text(en.updateRequiredBody), findsOneWidget);
      expect(find.text(en.updateLater), findsNothing);

      await tester.tap(find.text(en.updateNow));
      await tester.pumpAndSettle();
      expect(opened.single.path, '/download');
    });

    testWidgets('the optional prompt offers Update and Later', (tester) async {
      final repo = FakeVersionRepository(_release);
      final opened = <Uri>[];
      final overrides = overridesFor(repo, opened: opened);
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        localizedApp(
          Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const UpdatePrompter(child: Scaffold(body: Text('home')));
            },
          ),
          overrides: overrides,
        ),
      );
      await widgetRef.read(updateControllerProvider.notifier).check();
      await tester.pumpAndSettle();

      expect(find.text(en.updateAvailableTitle), findsOneWidget);
      expect(find.text(en.updateAvailableBody('1.5.0')), findsOneWidget);

      await tester.tap(find.text(en.updateLater));
      await tester.pumpAndSettle();
      expect(find.text(en.updateAvailableTitle), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(opened, isEmpty);
      expect(widgetRef.read(updateControllerProvider).showOptionalPrompt, isFalse);
    });

    testWidgets('Update in the optional prompt opens the download page', (tester) async {
      final opened = <Uri>[];
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        localizedApp(
          Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const UpdatePrompter(child: Scaffold(body: Text('home')));
            },
          ),
          overrides: overridesFor(FakeVersionRepository(_release), opened: opened),
        ),
      );
      await widgetRef.read(updateControllerProvider.notifier).check();
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.updateNow));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('$_server/download')]);
    });
  });
}
