import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/night_sky.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/statistics_repository.dart';
import '../domain/statistics.dart';

class StatisticsState {
  const StatisticsState({
    required this.period,
    required this.from,
    required this.to,
    this.result,
  });

  final StatsPeriod period;
  final DateTime from;
  final DateTime to;

  /// Null until "Validate Period" is pressed.
  final AsyncValue<List<DailyStatistics>>? result;

  bool get rangeInvalid => from.isAfter(to);

  StatisticsState copyWith({
    StatsPeriod? period,
    DateTime? from,
    DateTime? to,
    AsyncValue<List<DailyStatistics>>? Function()? result,
  }) => StatisticsState(
    period: period ?? this.period,
    from: from ?? this.from,
    to: to ?? this.to,
    result: result == null ? this.result : result(),
  );
}

class StatisticsController extends Notifier<StatisticsState> {
  @override
  StatisticsState build() {
    // Start over when a different volunteer/region signs in.
    ref.watch(authControllerProvider.select((a) => a.value?.region?.id));
    final range = StatsPeriod.daily.rangeFor(ref.read(clockProvider)());
    return StatisticsState(
      period: StatsPeriod.daily,
      from: range.from,
      to: range.to,
    );
  }

  void selectPeriod(StatsPeriod period) {
    final range = period.rangeFor(
      ref.read(clockProvider)(),
      customFrom: state.from,
      customTo: state.to,
    );
    state = state.copyWith(period: period, from: range.from, to: range.to);
  }

  void setFrom(DateTime date) =>
      state = state.copyWith(period: StatsPeriod.custom, from: dateOnly(date));

  void setTo(DateTime date) =>
      state = state.copyWith(period: StatsPeriod.custom, to: dateOnly(date));

  Future<void> validate() async {
    if (state.rangeInvalid) return;
    state = state.copyWith(result: () => const AsyncLoading());
    final result = await AsyncValue.guard(() {
      final region = requireRegion(ref);
      return ref
          .read(statisticsRepositoryProvider)
          .fetch(region.id, state.from, state.to);
    });
    if (ref.mounted) state = state.copyWith(result: () => result);
  }

  /// "Choose another period".
  void reset() => state = state.copyWith(result: () => null);
}

final statisticsControllerProvider =
    NotifierProvider<StatisticsController, StatisticsState>(
      StatisticsController.new,
    );

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statisticsControllerProvider);
    final controller = ref.read(statisticsControllerProvider.notifier);
    final result = stats.result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        actions: [
          if (result is AsyncData)
            TextButton(
              onPressed: controller.reset,
              child: const Text('Choose another period'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: result == null ? () async {} : controller.validate,
        notificationPredicate: (_) => result is AsyncData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            120,
          ),
          children: [
            if (result == null || result is AsyncLoading)
              _PeriodForm(
                state: stats,
                controller: controller,
                loading: result is AsyncLoading,
              ),
            if (result case AsyncError(:final error))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xl),
                child: ErrorView(
                  failure: toAppFailure(error),
                  onRetry: controller.validate,
                ),
              ),
            if (result case AsyncData(:final value)) ...[
              _SummaryCard(days: value, from: stats.from, to: stats.to),
              const SizedBox(height: AppSpacing.lg),
              for (final day in value) ...[
                _DayCard(day: day),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PeriodForm extends StatelessWidget {
  const _PeriodForm({
    required this.state,
    required this.controller,
    required this.loading,
  });

  final StatisticsState state;
  final StatisticsController controller;
  final bool loading;

  Future<void> _pick(BuildContext context, {required bool from}) async {
    final initial = from ? state.from : state.to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    from ? controller.setFrom(picked) : controller.setTo(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose a period:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<StatsPeriod>(
          showSelectedIcon: false,
          segments: [
            for (final p in StatsPeriod.values)
              ButtonSegment(value: p, label: Text(p.label)),
          ],
          selected: {state.period},
          onSelectionChanged: (s) => controller.selectPeriod(s.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.event_rounded,
                  color: AppColors.goldDeep,
                ),
                title: const Text('From'),
                trailing: Text(
                  formatDate(state.from),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => _pick(context, from: true),
              ),
              const Divider(indent: AppSpacing.lg),
              ListTile(
                leading: const Icon(
                  Icons.event_available_rounded,
                  color: AppColors.goldDeep,
                ),
                title: const Text('To'),
                trailing: Text(
                  formatDate(state.to),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => _pick(context, from: false),
              ),
            ],
          ),
        ),
        if (state.rangeInvalid)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm, left: 4),
            child: Text(
              'From date should be before or equal to To date.',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: loading || state.rangeInvalid ? null : controller.validate,
          child: loading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Validate Period'),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.days,
    required this.from,
    required this.to,
  });

  final List<DailyStatistics> days;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final summary = StatisticsSummary(days);
    final range = isSameDay(from, to)
        ? formatDate(from)
        : '${formatDate(from)} – ${formatDate(to)}';
    return NightSky(
      borderRadius: BorderRadius.circular(AppRadii.card),
      starCount: 18,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              range,
              style: const TextStyle(color: AppColors.goldSoft, fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${summary.totalMeals} meals served',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.sm,
              children: [
                _Metric('Persons', summary.persons),
                _Metric('Single', summary.singleMeal),
                _Metric('Family (×4)', summary.familyMeal),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final DailyStatistics day;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.inkMuted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              fontSize: strong ? 17 : 15,
            ),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              day.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.goldDeep,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            row(
              'Number of served persons:',
              '${day.persons} / ${day.totalPersons}',
            ),
            row('Family meals:', '${day.familyMeal}'),
            row('Single meals:', '${day.singleMeal}'),
            const Divider(),
            row('Total of served meals:', '${day.totalMeals}', strong: true),
          ],
        ),
      ),
    );
  }
}
