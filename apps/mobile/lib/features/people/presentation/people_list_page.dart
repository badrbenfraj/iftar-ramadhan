import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/night_sky.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/fasting_person.dart';
import 'people_controller.dart';

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
      if (mounted) {
        showAppSnackBar(
          context,
          e is NetworkFailure
              ? 'Offline — showing the last loaded list.'
              : e.message,
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleListProvider);
    final query = ref.watch(peopleSearchQueryProvider);
    final region = ref.watch(
      authControllerProvider.select((a) => a.value?.region?.name),
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        edgeOffset: 180,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                region: region,
                people: people.value,
                controller: _search,
                onQueryChanged: ref
                    .read(peopleSearchQueryProvider.notifier)
                    .update,
              ),
            ),
            ...switch (people) {
              AsyncData(:final value) => _listSlivers(value, query),
              AsyncError(:final error) when !people.hasValue => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    failure: toAppFailure(error),
                    onRetry: () => ref.invalidate(peopleListProvider),
                  ),
                ),
              ],
              _ when people.hasValue => _listSlivers(people.value!, query),
              _ => [
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: LoadingView(message: 'Fetching data'),
                ),
              ],
            },
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  List<Widget> _listSlivers(List<FastingPerson> all, String query) {
    if (all.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.groups_2_outlined,
            title: 'No fasting people yet',
            message: 'Add the first person to start distributing meals.',
            action: FilledButton.icon(
              onPressed: () => context.go('/add'),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add person'),
            ),
          ),
        ),
      ];
    }
    final filtered = all.where((p) => p.matches(query)).toList();
    if (filtered.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.search_off_rounded,
            title: 'No match for “${isolate(query)}”',
            message: 'Search by name, ID, CIN or phone.',
          ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverList.separated(
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) => _PersonTile(
            person: filtered[i],
            onTap: () => context.push('/people/${filtered[i].id}'),
          ),
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.region,
    required this.people,
    required this.controller,
    required this.onQueryChanged,
  });

  final String? region;
  final List<FastingPerson>? people;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final servedToday = people?.where((p) => p.isMealTakenToday()).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: NightSky(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              AppSpacing.gutter,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (region != null)
                  Text(
                    region!.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'List of fasting people',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (people != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${people!.length} registered · $servedToday served today',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: controller,
                  onChanged: onQueryChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search by Name or Id',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => controller.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                controller.clear();
                                onQueryChanged('');
                              },
                            ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
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
  const _PersonTile({required this.person, required this.onTap});

  final FastingPerson person;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final taken = person.isMealTakenToday();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.goldSoft.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(
                  '${person.id}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.night,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _meals(person),
                      style: const TextStyle(
                        color: AppColors.inkMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: taken ? 'Served today' : 'Not served yet today',
                child: Icon(
                  taken
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: taken ? AppColors.danger : AppColors.outline,
                  size: 22,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _meals(FastingPerson p) {
    final parts = [
      if (p.singleMeal > 0) '${p.singleMeal} single',
      if (p.familyMeal > 0) '${p.familyMeal} family',
    ];
    return parts.isEmpty ? 'No meals set' : parts.join(' · ');
  }
}
