import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/ramadan.dart';
import '../../../core/widgets/night_sky.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/statistics.dart';
import 'statistics_controller.dart';

/// The shell's bottom bar is 72 px tall and the body extends behind it.
const _tabBarHeight = 72.0;

class StatisticsPage extends ConsumerWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final stats = ref.watch(statisticsControllerProvider);
    final controller = ref.read(statisticsControllerProvider.notifier);
    final config = ref.watch(appConfigProvider);
    final day = ramadanDay(config.ramadanStart, ref.watch(clockProvider)());
    final days = stats.result.value;
    final served = days == null ? 0 : StatisticsSummary(days).persons;
    final bottomClearance =
        _tabBarHeight + MediaQuery.viewPaddingOf(context).bottom + 40;
    final presets = [
      (StatsPreset.tonight, l.presetTonight),
      (StatsPreset.week, l.presetWeek),
      // Hidden, not disabled, until the season's first day is configured.
      if (config.ramadanStart != null) (StatsPreset.ramadan, l.presetRamadan),
    ];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        edgeOffset: 220,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            SkyBand(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (day != null)
                    Row(
                      children: [
                        const Icon(Icons.nightlight_round, size: 14, color: AppPalette.gold),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            l.ramadanDay(ltr('$day')),
                            style: const TextStyle(fontSize: 12, color: AppPalette.gold),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    l.statsTitle,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      ltr('$served'),
                      style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w300, height: 1),
                    ),
                  ),
                  Text(
                    stats.preset == StatsPreset.tonight && days != null && days.isNotEmpty
                        ? l.ofPeopleServed(days.last.totalPersons)
                        : l.peopleServed,
                    style: const TextStyle(fontSize: 13, color: AppPalette.onSkyMuted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (preset, label) in presets)
                        _PresetChip(
                          label: label,
                          selected: stats.preset == preset,
                          onTap: () => controller.select(preset),
                        ),
                      if (stats.preset == StatsPreset.custom)
                        _PresetChip(label: l.presetCustom, selected: true, onTap: () {}),
                    ],
                  ),
                ],
              ),
            ),
            switch (stats.result) {
              AsyncError(:final error) => Padding(
                padding: const EdgeInsets.only(top: 24),
                child: ErrorView(failure: toAppFailure(error), onRetry: controller.refresh),
              ),
              AsyncData(:final value) => _Results(
                days: value,
                onCustom: () => _pickCustom(context, ref, stats),
              ),
              _ => const Padding(
                padding: EdgeInsets.only(top: 48),
                child: LoadingView(),
              ),
            },
            SizedBox(height: bottomClearance),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustom(BuildContext context, WidgetRef ref, StatisticsState stats) {
    final today = dateOnly(ref.read(clockProvider)());
    DateTime clamp(DateTime d) => d.isAfter(today) ? today : d;
    var from = clamp(stats.from);
    var to = clamp(stats.to);
    var invalid = false;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final l = AppLocalizations.of(sheetContext);
          Future<void> pick({required bool start}) async {
            final picked = await showDatePicker(
              context: sheetContext,
              initialDate: start ? from : to,
              firstDate: DateTime(2020),
              // The future has no statistics yet.
              lastDate: today,
            );
            if (picked != null) {
              setSheetState(() {
                invalid = false;
                start ? from = picked : to = picked;
              });
            }
          }

          return SingleChildScrollView(
            padding: EdgeInsetsDirectional.fromSTEB(
              20,
              0,
              20,
              24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.customDates, style: Theme.of(sheetContext).textTheme.titleMedium),
                ListTile(
                  leading: const Icon(Icons.event_rounded),
                  title: Text(l.fromDate),
                  trailing: Text(formatDate(from)),
                  onTap: () => pick(start: true),
                ),
                ListTile(
                  leading: const Icon(Icons.event_available_rounded),
                  title: Text(l.toDate),
                  trailing: Text(formatDate(to)),
                  onTap: () => pick(start: false),
                ),
                if (invalid)
                  Semantics(
                    liveRegion: true,
                    child: Text(l.rangeInvalid, style: TextStyle(color: sheetContext.colors.clay)),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final ok = await ref
                        .read(statisticsControllerProvider.notifier)
                        .setCustom(from, to);
                    if (!sheetContext.mounted) return;
                    if (ok) {
                      Navigator.of(sheetContext).pop();
                    } else {
                      setSheetState(() => invalid = true);
                    }
                  },
                  child: Text(l.apply),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        alignment: AlignmentDirectional.center,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppPalette.gold : AppPalette.onSky.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppPalette.gold : AppPalette.onSky.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: selected ? AppPalette.sky : AppPalette.onSky,
          ),
        ),
      ),
    ),
  );
}

class _Results extends StatelessWidget {
  const _Results({required this.days, required this.onCustom});

  final List<DailyStatistics> days;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final summary = StatisticsSummary(days);
    final figures = [
      _Figure(value: summary.totalMeals, label: l.figPortions),
      _Figure(value: summary.singleMeal, label: l.figSingle),
      _Figure(value: summary.familyMeal, label: l.figFamily),
    ];
    // Three tiles side by side stop fitting once text is scaled up.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final f in figures) ...[f, if (f != figures.last) const SizedBox(height: 10)],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: figures[0]),
                    const SizedBox(width: 10),
                    Expanded(child: figures[1]),
                    const SizedBox(width: 10),
                    Expanded(child: figures[2]),
                  ],
                ),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 6),
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onCustom,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(l.customDates),
            ),
          ),
        ),
        if (days.isEmpty)
          EmptyView(icon: Icons.insights_rounded, title: l.noStats)
        else ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 6),
            child: Text(l.byDay, style: TextStyle(fontSize: 12, color: c.inkMuted)),
          ),
          for (final day in days) _DayRow(day: day),
        ],
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              ltr('$value'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11.5, color: context.colors.inkMuted)),
        ],
      ),
    ),
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day});

  final DailyStatistics day;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final date = day.date;
    return Card(
      margin: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    date == null ? day.label : formatDate(date),
                    style: TextStyle(fontSize: 12.5, color: c.inkMuted),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${ltr('${day.totalMeals}')} ${l.figPortions}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: day.totalPersons == 0 ? 0 : day.persons / day.totalPersons,
                      minHeight: 8,
                      color: AppPalette.gold,
                      backgroundColor: c.tile,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // The bar is not the only carrier of the ratio.
                Text(
                  ltr('${day.persons} / ${day.totalPersons}'),
                  style: TextStyle(fontSize: 12.5, color: c.inkMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
