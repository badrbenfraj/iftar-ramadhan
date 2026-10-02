import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/app.dart';
import 'package:iftar_mobile/core/settings/settings_controller.dart';
import 'package:iftar_mobile/core/settings/settings_storage.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/people/presentation/people_controller.dart';

import '../support/fakes.dart';
import '../support/fonts.dart';

/// The phone gets no push when the day changes, so the list reloads when the
/// app comes back to the foreground on a new day.
void main() {
  setUpAll(loadAppFonts);

  final nextEvening = DateTime(2025, 3, 6, 18, 30);

  group('controller', () {
    late FakePeopleRepository repo;
    late DateTime now;
    late ProviderContainer container;

    setUp(() async {
      now = testNow;
      repo = FakePeopleRepository([person(1)]);
      container = ProviderContainer.test(
        overrides: testOverrides(repo, clock: () => now),
      );
      await container.read(authControllerProvider.future);
      await container.read(peopleListProvider.future);
    });

    PeopleListController list() => container.read(peopleListProvider.notifier);

    test('remembers when the list was loaded', () {
      expect(list().loadedAt, testNow);
    });

    test('the same day reloads nothing', () async {
      now = DateTime(2025, 3, 5, 23, 50);
      await list().reloadIfDayChanged();
      expect(repo.listCalls, 1);
    });

    test('a new day reloads the list and restamps it', () async {
      repo.people[2] = person(2, first: 'Aziza', last: 'Ouerghi');
      now = nextEvening;
      await list().reloadIfDayChanged();
      expect(repo.listCalls, 2);
      expect(list().loadedAt, nextEvening);
      expect(container.read(peopleListProvider).value, hasLength(2));
    });

    test('a failed reload keeps the list and tries again next time', () async {
      final failing = _FailingList();
      final c = ProviderContainer.test(
        overrides: testOverrides(failing, clock: () => now),
      );
      await c.read(authControllerProvider.future);
      await c.read(peopleListProvider.future);
      failing.fail = true;
      now = nextEvening;
      await c.read(peopleListProvider.notifier).reloadIfDayChanged();
      expect(c.read(peopleListProvider).value, hasLength(1));
      failing.fail = false;
      await c.read(peopleListProvider.notifier).reloadIfDayChanged();
      expect(failing.calls, 3);
      expect(c.read(peopleListProvider.notifier).loadedAt, nextEvening);
    });
  });

  group('app lifecycle', () {
    late FakePeopleRepository repo;
    late DateTime now;

    Future<void> boot(WidgetTester tester) async {
      now = testNow;
      repo = FakePeopleRepository([person(1)]);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            ...testOverrides(repo, clock: () => now),
            settingsStorageProvider.overrideWithValue(MemorySettingsStorage()),
          ],
          child: const IftarApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.listCalls, 1);
    }

    Future<void> background(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    }

    Future<void> resume(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('resuming on a new day reloads the people list', (tester) async {
      await boot(tester);
      await background(tester);
      now = nextEvening;
      await resume(tester);
      expect(repo.listCalls, 2);
    });

    testWidgets('resuming the same day does not', (tester) async {
      await boot(tester);
      await background(tester);
      now = DateTime(2025, 3, 5, 22);
      await resume(tester);
      expect(repo.listCalls, 1);
    });
  });
}

class _FailingList extends FakePeopleRepository {
  _FailingList() : super([person(1)]);

  bool fail = false;
  int calls = 0;

  @override
  Future<List<FastingPerson>> list(int regionId) async {
    calls++;
    if (fail) throw StateError('offline');
    return super.list(regionId);
  }
}
