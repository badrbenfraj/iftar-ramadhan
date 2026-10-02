import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/statistics_repository.dart';
import '../domain/statistics.dart';

class StatisticsState {
  const StatisticsState({
    required this.preset,
    required this.from,
    required this.to,
    this.result = const AsyncLoading(),
  });

  final StatsPreset preset;
  final DateTime from;
  final DateTime to;
  final AsyncValue<List<DailyStatistics>> result;

  StatisticsState copyWith({
    StatsPreset? preset,
    DateTime? from,
    DateTime? to,
    AsyncValue<List<DailyStatistics>>? result,
  }) => StatisticsState(
    preset: preset ?? this.preset,
    from: from ?? this.from,
    to: to ?? this.to,
    result: result ?? this.result,
  );
}

class StatisticsController extends Notifier<StatisticsState> {
  int _request = 0;

  DateTime _now() => ref.read(clockProvider)();

  @override
  StatisticsState build() {
    // Start over when a different volunteer/region signs in.
    final auth = ref.watch(
      authControllerProvider.select((a) => (a.isLoading, a.value?.region?.id)),
    );
    final range = presetRange(StatsPreset.tonight, _now());
    // While sign-in is still resolving there is no region to ask for; this
    // build runs again once it settles.
    if (!auth.$1) scheduleMicrotask(_fetch);
    return StatisticsState(
      preset: StatsPreset.tonight,
      from: range.from,
      to: range.to,
    );
  }

  Future<void> select(StatsPreset preset) async {
    if (preset == StatsPreset.custom) return;
    final start = ref.read(appConfigProvider).ramadanStart;
    // Ramadan needs its configured first day; the page hides the chip without it.
    if (preset == StatsPreset.ramadan && start == null) return;
    final range = presetRange(preset, _now(), ramadanStart: start);
    state = state.copyWith(preset: preset, from: range.from, to: range.to);
    await _fetch();
  }

  /// Returns false (and fetches nothing) when [from] is after [to], or when
  /// [to] is in the future.
  Future<bool> setCustom(DateTime from, DateTime to) async {
    final start = dateOnly(from);
    final end = dateOnly(to);
    if (start.isAfter(end) || end.isAfter(dateOnly(_now()))) return false;
    state = state.copyWith(preset: StatsPreset.custom, from: start, to: end);
    await _fetch();
    return true;
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    final request = ++_request;
    state = state.copyWith(result: const AsyncLoading());
    final result = await AsyncValue.guard(() {
      final region = requireRegion(ref);
      return ref
          .read(statisticsRepositoryProvider)
          .fetch(region.id, state.from, state.to);
    });
    // Ignore answers to older requests (quick preset taps).
    if (ref.mounted && request == _request) {
      state = state.copyWith(result: result);
    }
  }
}

final statisticsControllerProvider =
    NotifierProvider<StatisticsController, StatisticsState>(
      StatisticsController.new,
    );
