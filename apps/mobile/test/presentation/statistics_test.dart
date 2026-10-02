import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/config/app_config.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/providers.dart';
import 'package:iftar_mobile/core/utils/formatters.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/statistics/data/statistics_repository.dart';
import 'package:iftar_mobile/features/statistics/domain/statistics.dart';
import 'package:iftar_mobile/features/statistics/presentation/statistics_controller.dart';
import 'package:iftar_mobile/features/statistics/presentation/statistics_page.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';
import '../support/fonts.dart';

class FakeStatisticsRepository implements StatisticsRepository {
  FakeStatisticsRepository({this.days, this.failure});

  /// Replaces the single default day when set (may be empty).
  final List<DailyStatistics>? days;

  /// Thrown by [fetch] while non-null.
  AppFailure? failure;

  /// When set, [fetch] waits for it before answering.
  Completer<void>? gate;

  final calls = <(DateTime, DateTime)>[];

  @override
  Future<List<DailyStatistics>> fetch(int regionId, DateTime from, DateTime to) async {
    calls.add((from, to));
    await gate?.future;
    final f = failure;
    if (f != null) throw f;
    return days ??
        [
          DailyStatistics.fromJson({
            'date': 'Wed Mar 05 2025',
            'statistics': {'persons': 3, 'totalPersons': 9, 'singleMeal': 2, 'familyMeal': 4, 'totalMeals': 6},
          }),
        ];
  }
}

DailyStatistics day(String label, {int persons = 3, int total = 9}) => DailyStatistics.fromJson({
  'date': label,
  'statistics': {
    'persons': persons,
    'totalPersons': total,
    'singleMeal': 2,
    'familyMeal': 4,
    'totalMeals': 6,
  },
});

void main() {
  setUpAll(loadAppFonts);

  late FakeStatisticsRepository stats;
  setUp(() => stats = FakeStatisticsRepository());

  group('presetRange', () {
    test('the week runs Sunday to Saturday: a Saturday now', () {
      final r = presetRange(StatsPreset.week, DateTime(2025, 3, 8, 23, 59));
      expect(r, (from: DateTime(2025, 3, 2), to: DateTime(2025, 3, 8)));
    });

    test('a Sunday now starts its own week', () {
      final r = presetRange(StatsPreset.week, DateTime(2025, 3, 2, 0, 5));
      expect(r, (from: DateTime(2025, 3, 2), to: DateTime(2025, 3, 8)));
    });

    test('the week crosses a month boundary', () {
      // Wed 2025-04-02: week is Sun Mar 30 .. Sat Apr 5.
      final r = presetRange(StatsPreset.week, DateTime(2025, 4, 2));
      expect(r, (from: DateTime(2025, 3, 30), to: DateTime(2025, 4, 5)));
    });

    test('Ramadan runs from the first day to today', () {
      final r = presetRange(StatsPreset.ramadan, DateTime(2025, 3, 5, 18), ramadanStart: DateTime(2025, 3, 1));
      expect(r, (from: DateTime(2025, 3, 1), to: DateTime(2025, 3, 5)));
    });

    test('Ramadan never reaches into the future before it starts', () {
      final r = presetRange(StatsPreset.ramadan, DateTime(2025, 2, 20), ramadanStart: DateTime(2025, 3, 1));
      expect(r, (from: DateTime(2025, 2, 20), to: DateTime(2025, 2, 20)));
    });

    test('Ramadan stops at day 30', () {
      final r = presetRange(StatsPreset.ramadan, DateTime(2025, 5, 1), ramadanStart: DateTime(2025, 3, 1));
      expect(r, (from: DateTime(2025, 3, 1), to: DateTime(2025, 3, 30)));
    });
  });

  group('controller', () {
    Future<ProviderContainer> container({DateTime? ramadanStart}) async {
      final c = ProviderContainer.test(
        overrides: [
          ...testOverrides(FakePeopleRepository([])),
          statisticsRepositoryProvider.overrideWithValue(stats),
          appConfigProvider.overrideWithValue(
            AppConfig(apiBaseUrl: 'http://test', environment: 'test', ramadanStart: ramadanStart),
          ),
        ],
      );
      await c.read(authControllerProvider.future);
      c.listen(statisticsControllerProvider, (_, _) {});
      await pumpEventQueue();
      return c;
    }

    test('tonight loads at once; another preset loads on tap, no validate step', () async {
      final c = await container();
      expect(stats.calls.single, (DateTime(2025, 3, 5), DateTime(2025, 3, 5)));
      await c.read(statisticsControllerProvider.notifier).select(StatsPreset.week);
      expect(stats.calls.last, (DateTime(2025, 3, 2), DateTime(2025, 3, 8)));
      expect(c.read(statisticsControllerProvider).result.value, hasLength(1));
    });

    test('Ramadan counts from the configured first day', () async {
      final c = await container(ramadanStart: DateTime(2025, 3, 1));
      await c.read(statisticsControllerProvider.notifier).select(StatsPreset.ramadan);
      expect(stats.calls.last, (DateTime(2025, 3, 1), DateTime(2025, 3, 5)));
    });

    test('Ramadan before it starts requests no future day', () async {
      final c = await container(ramadanStart: DateTime(2025, 3, 20));
      await c.read(statisticsControllerProvider.notifier).select(StatsPreset.ramadan);
      expect(stats.calls.last, (DateTime(2025, 3, 5), DateTime(2025, 3, 5)));
    });

    test('Ramadan without a configured start fetches nothing', () async {
      final c = await container();
      await c.read(statisticsControllerProvider.notifier).select(StatsPreset.ramadan);
      expect(stats.calls, hasLength(1));
      expect(c.read(statisticsControllerProvider).preset, StatsPreset.tonight);
    });

    test('an inverted custom range is rejected without fetching', () async {
      final c = await container();
      final ok = await c
          .read(statisticsControllerProvider.notifier)
          .setCustom(DateTime(2025, 3, 8), DateTime(2025, 3, 2));
      expect(ok, isFalse);
      expect(stats.calls, hasLength(1));
    });

    test('a custom range in the future is rejected without fetching', () async {
      final c = await container();
      final ok = await c
          .read(statisticsControllerProvider.notifier)
          .setCustom(DateTime(2025, 3, 5), DateTime(2025, 3, 6));
      expect(ok, isFalse);
      expect(stats.calls, hasLength(1));
      expect(c.read(statisticsControllerProvider).preset, StatsPreset.tonight);
    });

    test('a valid custom range fetches and is selected', () async {
      final c = await container();
      final ok = await c
          .read(statisticsControllerProvider.notifier)
          .setCustom(DateTime(2025, 3, 1), DateTime(2025, 3, 5));
      expect(ok, isTrue);
      expect(stats.calls.last, (DateTime(2025, 3, 1), DateTime(2025, 3, 5)));
      expect(c.read(statisticsControllerProvider).preset, StatsPreset.custom);
    });

    test('refresh refetches the current range; a failure lands in the state', () async {
      final c = await container();
      stats.failure = const NetworkFailure();
      await c.read(statisticsControllerProvider.notifier).refresh();
      expect(stats.calls, hasLength(2));
      expect(c.read(statisticsControllerProvider).result.hasError, isTrue);
    });
  });

  group('page', () {
    Future<void> pumpPage(
      WidgetTester tester, {
      DateTime? ramadanStart,
      Locale locale = const Locale('en'),
      DateTime Function()? clock,
      bool settle = true,
    }) async {
      await tester.pumpWidget(
        localizedApp(
          const StatisticsPage(),
          locale: locale,
          overrides: [
            ...testOverrides(FakePeopleRepository([]), clock: clock),
            statisticsRepositoryProvider.overrideWithValue(stats),
            appConfigProvider.overrideWithValue(
              AppConfig(apiBaseUrl: 'http://test', environment: 'test', ramadanStart: ramadanStart),
            ),
          ],
        ),
      );
      // A loading spinner never settles.
      settle ? await tester.pumpAndSettle() : await tester.pump(const Duration(milliseconds: 50));
    }

    void phone(WidgetTester tester, {double scale = 1}) {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    testWidgets('shows the hero number, figures and a localized day', (tester) async {
      await pumpPage(tester);
      expect(find.text(ltr('3')), findsOneWidget);
      expect(find.text(en.ofPeopleServed(9)), findsOneWidget);
      expect(find.text(en.presetRamadan), findsNothing); // not configured: hidden
      expect(find.text(formatDate(DateTime(2025, 3, 5))), findsOneWidget);
    });

    testWidgets('Ramadan chip appears when configured, with the day of Ramadan', (tester) async {
      await pumpPage(tester, ramadanStart: DateTime(2025, 3, 1));
      expect(find.text(en.presetRamadan), findsOneWidget);
      expect(find.text(en.ramadanDay(ltr('5'))), findsOneWidget);
      await tester.tap(find.text(en.presetRamadan));
      await tester.pumpAndSettle();
      expect(stats.calls.last, (DateTime(2025, 3, 1), DateTime(2025, 3, 5)));
    });

    testWidgets('chips expose a selected state and are at least 48 tall', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);
      Matcher chip(String label, {required bool selected}) => matchesSemantics(
        label: label,
        isButton: true,
        isSelected: selected,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      );
      expect(tester.getSemantics(find.text(en.presetTonight)), chip(en.presetTonight, selected: true));
      expect(tester.getSemantics(find.text(en.presetWeek)), chip(en.presetWeek, selected: false));
      final box = find.ancestor(of: find.text(en.presetWeek), matching: find.byType(InkWell));
      expect(tester.getSize(box).height, greaterThanOrEqualTo(48));
      handle.dispose();
    });

    testWidgets('tapping a preset fetches at once', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text(en.presetWeek));
      await tester.pumpAndSettle();
      expect(stats.calls.last, (DateTime(2025, 3, 2), DateTime(2025, 3, 8)));
    });

    testWidgets('an unparseable day label is shown as is', (tester) async {
      stats = FakeStatisticsRepository(days: [day('Someday soon')]);
      await pumpPage(tester);
      expect(find.text('Someday soon'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the day bar is not colour-alone: the ratio is written out', (tester) async {
      await pumpPage(tester);
      expect(find.text(ltr('3 / 9')), findsOneWidget);
    });

    testWidgets('a failure shows the error with a retry that refetches', (tester) async {
      stats.failure = const NetworkFailure();
      await pumpPage(tester);
      expect(find.text(en.tryAgain), findsOneWidget);
      stats.failure = null;
      await tester.tap(find.text(en.tryAgain));
      await tester.pumpAndSettle();
      expect(stats.calls, hasLength(2));
      expect(find.text(en.tryAgain), findsNothing);
      expect(find.text(ltr('3')), findsOneWidget);
    });

    testWidgets('a custom range from the sheet applies; an inverted one shows the message', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text(en.customDates));
      await tester.pumpAndSettle();
      // To: pick the 3rd, while From stays on the 5th.
      await tester.tap(find.text(en.toDate));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('3')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.apply));
      await tester.pumpAndSettle();
      expect(find.text(en.rangeInvalid), findsOneWidget);
      expect(stats.calls, hasLength(1));
      // Fix it: From the 1st.
      await tester.tap(find.text(en.fromDate));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('1')));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.apply));
      await tester.pumpAndSettle();
      expect(stats.calls.last, (DateTime(2025, 3, 1), DateTime(2025, 3, 3)));
      expect(find.text(en.presetCustom), findsOneWidget);
    });

    testWidgets('Custom dates is reachable when the load failed', (tester) async {
      stats.failure = const NetworkFailure();
      await pumpPage(tester);
      expect(find.text(en.tryAgain), findsOneWidget);
      await tester.tap(find.text(en.customDates));
      await tester.pumpAndSettle();
      expect(find.text(en.fromDate), findsOneWidget);
      expect(find.text(en.apply), findsOneWidget);
    });

    testWidgets('Custom dates is reachable while loading', (tester) async {
      stats.gate = Completer<void>();
      await pumpPage(tester, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text(en.customDates));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(en.fromDate), findsOneWidget);
      stats.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('the Custom chip reopens the sheet', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text(en.customDates));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.apply));
      await tester.pumpAndSettle();
      expect(find.text(en.fromDate), findsNothing);
      await tester.tap(find.text(en.presetCustom));
      await tester.pumpAndSettle();
      expect(find.text(en.fromDate), findsOneWidget);
      expect(find.text(en.apply), findsOneWidget);
    });

    testWidgets('an end date in the future says so, not "start before end"', (tester) async {
      var now = testNow;
      await pumpPage(tester, clock: () => now);
      await tester.tap(find.text(en.customDates));
      await tester.pumpAndSettle();
      // Midnight rolls back under the open sheet: the sheet's end (the 5th) is now ahead of today.
      now = DateTime(2025, 3, 4, 23, 59);
      await tester.tap(find.text(en.apply));
      await tester.pumpAndSettle();
      expect(find.text(en.rangeInFuture), findsOneWidget);
      expect(find.text(en.rangeInvalid), findsNothing);
      expect(stats.calls, hasLength(1));
    });

    for (final inset in [34.0, 0.0]) {
      testWidgets('the last row clears the 72 px bar and the docked button at inset $inset', (tester) async {
        phone(tester);
        tester.view.padding = FakeViewPadding(bottom: inset);
        tester.view.viewPadding = FakeViewPadding(bottom: inset);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        stats = FakeStatisticsRepository(
          days: [for (var d = 1; d <= 14; d++) day('Mon Mar ${d.toString().padLeft(2, '0')} 2025')],
        );
        await pumpPage(tester);
        await tester.drag(find.byType(ListView), const Offset(0, -5000));
        await tester.pumpAndSettle();
        final last = find.text(formatDate(DateTime(2025, 3, 14)));
        expect(last, findsOneWidget);
        final bottom = tester.getBottomLeft(find.ancestor(of: last, matching: find.byType(Card)).first).dy;
        expect(760 - bottom, greaterThanOrEqualTo(72 + inset + 40));
      });
    }

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      for (final scale in [1.3, 2.0]) {
        final name = '360x760, text $scale, ${locale.languageCode}';
        final l = locale.languageCode == 'ar' ? ar : en;
        testWidgets('lays out with data at $name', (tester) async {
          phone(tester, scale: scale);
          await pumpPage(tester, locale: locale, ramadanStart: DateTime(2025, 3, 1));
          expect(find.text(ltr('3')), findsOneWidget);
          expect(find.text(l.statsTitle), findsOneWidget);
          expect(find.text(l.presetRamadan), findsOneWidget);
          expect(find.text(l.figPortions), findsWidgets);
          expect(tester.takeException(), isNull);
        });

        testWidgets('lays out an empty result at $name', (tester) async {
          phone(tester, scale: scale);
          stats = FakeStatisticsRepository(days: const []);
          await pumpPage(tester, locale: locale);
          expect(find.text(ltr('0')), findsWidgets);
          expect(find.text(l.noStats), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
