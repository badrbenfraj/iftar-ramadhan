import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/scan/presentation/scan_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakePeopleRepository repo;
  late ProviderContainer container;
  late DateTime now;

  ScanController controller() =>
      container.read(scanControllerProvider.notifier);
  ScanState state() => container.read(scanControllerProvider);

  setUp(() async {
    now = testNow;
    repo = FakePeopleRepository([
      person(101),
      person(102, takenToday: true, first: 'Aziza', last: 'Ouerghi'),
    ]);
    container = ProviderContainer.test(
      overrides: testOverrides(repo, clock: () => now),
    );
    // Keep the auto-dispose controller alive and let auth resolve.
    container.listen(scanControllerProvider, (_, _) {});
    await container.read(authControllerProvider.future);
  });

  test(
    'valid QR for an eligible person → ready, then confirm → confirmed',
    () async {
      await controller().onDetected('101');
      expect(state().status, isA<ScanReady>());
      expect(state().acceptsScans, isFalse, reason: 'pending decision');

      await controller().confirm();
      final status = state().status;
      expect(status, isA<ScanConfirmed>());
      expect((status as ScanConfirmed).person.isMealTakenToday(now), isTrue);
      expect(state().servedCount, 1);
      expect(repo.confirmCalls, 1);
    },
  );

  test('phone/comment edits are sent with the confirmation', () async {
    await controller().onDetected('101');
    controller().editContact(phone: '22123456', comment: 'diabetic');
    await controller().confirm();
    expect(repo.lastConfirmBody, (phone: '22123456', comment: 'diabetic'));
  });

  test(
    'person who already collected today → already taken, no confirm',
    () async {
      await controller().onDetected('102');
      final status = state().status;
      expect(status, isA<ScanAlreadyTaken>());
      expect((status as ScanAlreadyTaken).takenAt, isNotNull);
      expect(repo.confirmCalls, 0);
      expect(state().acceptsScans, isTrue);
    },
  );

  test('server rejects a duplicate (another device won the race)', () async {
    await controller().onDetected('101');
    // Someone else confirms on another phone meanwhile.
    repo.people[101] = person(101, takenToday: true);
    await controller().confirm();
    expect(state().status, isA<ScanAlreadyTaken>());
    expect(state().servedCount, 0);
  });

  test('non-numeric QR → invalid code', () async {
    await controller().onDetected('WIFI:S:guest;;');
    expect(state().status, isA<ScanInvalidCode>());
  });

  test('unknown ID → not found', () async {
    await controller().onDetected('999');
    final status = state().status;
    expect(status, isA<ScanNotFound>());
    expect((status as ScanNotFound).personId, 999);
  });

  test('network error on lookup → failed, retry succeeds', () async {
    repo.nextGetFailure = const NetworkFailure();
    await controller().onDetected('101');
    final status = state().status;
    expect(status, isA<ScanFailed>());
    expect((status as ScanFailed).duringConfirm, isFalse);

    await controller().retry();
    expect(state().status, isA<ScanReady>());
  });

  test(
    'server error on confirm → failed and camera stays blocked until resolved',
    () async {
      await controller().onDetected('101');
      repo.nextConfirmFailure = const ServerFailure(statusCode: 500);
      await controller().confirm();
      final status = state().status;
      expect(status, isA<ScanFailed>());
      expect((status as ScanFailed).duringConfirm, isTrue);
      expect(state().acceptsScans, isFalse);

      await controller().retry();
      expect(state().status, isA<ScanConfirmed>());
    },
  );

  test(
    'lost response after the server committed is not reported as a duplicate',
    () async {
      await controller().onDetected('101');
      repo
        ..nextConfirmFailure = const TimeoutFailure()
        ..applyThenFailConfirm = true;
      await controller().confirm();
      expect(state().status, isA<ScanFailed>());

      await controller().retry(); // server now answers 409 for our own write
      expect(state().status, isA<ScanConfirmed>());
      expect(state().servedCount, 1);
    },
  );

  test('the same card held in view is not re-read; a new card is', () async {
    await controller().onDetected('102');
    expect(state().status, isA<ScanAlreadyTaken>());

    now = now.add(const Duration(seconds: 1));
    await controller().onDetected('102'); // same frame stream
    expect(repo.confirmCalls, 0);
    expect(state().status, isA<ScanAlreadyTaken>());

    await controller().onDetected('101'); // next person in the queue
    expect(state().status, isA<ScanReady>());
  });

  test(
    'camera detections are ignored while a person awaits confirmation',
    () async {
      await controller().onDetected('101');
      await controller().onDetected('102');
      final status = state().status;
      expect(status, isA<ScanReady>());
      expect((status as ScanReady).person.id, 101);
    },
  );

  test('manual entry bypasses the duplicate filter', () async {
    await controller().onDetected('102');
    controller().scanNext();
    await controller().submitManual('102');
    expect(state().status, isA<ScanAlreadyTaken>());
  });

  test('account without region → explicit failure', () async {
    final noRegion = ProviderContainer.test(
      overrides: testOverrides(repo, user: null),
    );
    noRegion.listen(scanControllerProvider, (_, _) {});
    await noRegion.read(authControllerProvider.future);
    await noRegion.read(scanControllerProvider.notifier).onDetected('101');
    final status = noRegion.read(scanControllerProvider).status;
    expect(status, isA<ScanFailed>());
    expect((status as ScanFailed).failure, isA<AppStateFailure>());
  });
}
