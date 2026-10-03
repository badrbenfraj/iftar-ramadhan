import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/ramadan.dart';
import '../../../core/widgets/night_sky.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/fasting_person.dart';
import 'people_controller.dart';
import 'people_filter.dart';

/// The shell's bottom bar is 72 px tall and the body extends behind it.
const _tabBarHeight = 72.0;

class PeopleListPage extends ConsumerStatefulWidget {
  const PeopleListPage({super.key});

  @override
  ConsumerState<PeopleListPage> createState() => _PeopleListPageState();
}

class _PeopleListPageState extends ConsumerState<PeopleListPage> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(peopleSearchQueryProvider),
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      await ref.read(peopleListProvider.notifier).refresh();
    } on AppFailure catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context);
      showAppSnackBar(
        context,
        e is NetworkFailure ? l.offlineLastList : failureText(l, e),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final people = ref.watch(peopleListProvider);
    final query = ref.watch(peopleSearchQueryProvider);
    final filter = ref.watch(peopleFilterProvider);
    final now = ref.watch(clockProvider)();
    final day = ramadanDay(ref.watch(appConfigProvider).ramadanStart, now);
    final bottomClearance =
        _tabBarHeight + MediaQuery.viewPaddingOf(context).bottom + 40;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 200,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                ramadanDay: day,
                counts: people.hasValue ? countPeople(people.value!, now) : null,
                controller: _search,
                onQueryChanged: ref.read(peopleSearchQueryProvider.notifier).update,
              ),
            ),
            if (people.hasValue && people.value!.isNotEmpty)
              SliverToBoxAdapter(
                child: _FilterRow(
                  counts: countPeople(people.value!, now),
                  selected: filter,
                  onSelect: ref.read(peopleFilterProvider.notifier).select,
                ),
              ),
            ...switch (people) {
              AsyncData(:final value) => _listSlivers(l, value, query, filter, now),
              AsyncError(:final error) when !people.hasValue => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    failure: toAppFailure(error),
                    onRetry: () => ref.invalidate(peopleListProvider),
                  ),
                ),
              ],
              _ when people.hasValue => _listSlivers(l, people.value!, query, filter, now),
              _ => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: LoadingView(message: l.loading),
                ),
              ],
            },
            SliverToBoxAdapter(child: SizedBox(height: bottomClearance)),
          ],
        ),
      ),
    );
  }

  List<Widget> _listSlivers(
    AppLocalizations l,
    List<FastingPerson> all,
    String query,
    PeopleFilter filter,
    DateTime now,
  ) {
    if (all.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.groups_2_outlined,
            title: l.noPeopleTitle,
            message: l.noPeopleMessage,
            action: FilledButton.icon(
              onPressed: () => context.go('/add'),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(l.addPerson),
            ),
          ),
        ),
      ];
    }
    final filtered = applyPeopleFilter(all, filter: filter, query: query, now: now);
    if (filtered.isEmpty) {
      final noQuery = query.trim().isEmpty;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: noQuery ? Icons.nightlight_round : Icons.search_off_rounded,
            title: switch ((noQuery, filter)) {
              (true, PeopleFilter.waiting) => l.everyoneServed,
              (true, PeopleFilter.served) => l.nobodyServedYet,
              _ => l.noMatch(isolate(query.trim())),
            },
            message: noQuery ? null : l.searchTip,
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 0),
        sliver: SliverList.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _PersonTile(
            person: filtered[i],
            now: now,
            onTap: () => context.push('/people/${filtered[i].id}'),
          ),
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.ramadanDay,
    required this.counts,
    required this.controller,
    required this.onQueryChanged,
  });

  final int? ramadanDay;
  final PeopleCounts? counts;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final counts = this.counts;
    return SkyBand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ramadanDay != null)
            Row(
              children: [
                const Icon(Icons.nightlight_round, size: 14, color: AppPalette.gold),
                const SizedBox(width: 6),
                Text(
                  l.ramadanDay(ltr('$ramadanDay')),
                  style: const TextStyle(fontSize: 12, color: AppPalette.gold),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Text(
            l.peopleTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
          if (counts != null) ...[
            const SizedBox(height: 2),
            Text(
              l.peopleCount(ltr('${counts.total}'), ltr('${counts.served}')),
              style: const TextStyle(fontSize: 13, color: AppPalette.onSkyMuted),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: counts.total == 0 ? 0 : counts.served / counts.total,
                minHeight: 3,
                color: AppPalette.mint,
                backgroundColor: AppPalette.onSky.withValues(alpha: 0.14),
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.searchPeople,
              prefixIcon: const Icon(Icons.search_rounded),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.field),
                borderSide: BorderSide.none,
              ),
              suffixIcon: ListenableBuilder(
                listenable: controller,
                builder: (context, _) => controller.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: l.clearSearch,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          controller.clear();
                          onQueryChanged('');
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.counts, required this.selected, required this.onSelect});

  final PeopleCounts counts;
  final PeopleFilter selected;
  final ValueChanged<PeopleFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = [
      (PeopleFilter.all, l.filterAll, counts.total),
      (PeopleFilter.waiting, l.filterWaiting, counts.waiting),
      (PeopleFilter.served, l.filterServed, counts.served),
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 2),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (filter, label, count) in items)
            _FilterChip(
              label: label,
              count: count,
              selected: filter == selected,
              onTap: () => onSelect(filter),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? AppPalette.onSky : c.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppPalette.sky : c.surface,
            border: Border.all(color: selected ? AppPalette.sky : c.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: fg),
                ),
                const SizedBox(width: 6),
                Text(
                  ltr('$count'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.now, required this.onTap});

  final FastingPerson person;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final meals = [
      if (person.singleMeal > 0) l.mealSingleCount(person.singleMeal),
      if (person.familyMeal > 0) l.mealFamilyCount(person.familyMeal),
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 50),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: c.chip,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(
                  ltr(person.id.toString().padLeft(4, '0')),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.chipInk,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isolate(person.fullName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        StatusChip(person: person, now: now),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            meals,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: c.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
