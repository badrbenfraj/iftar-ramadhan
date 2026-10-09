import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/volunteers_repository.dart';
import '../domain/volunteer.dart';
import 'join_code_card.dart';
import 'volunteers_controller.dart';

/// Profile → Volunteers (security spec §8): join code, then accounts by
/// status. Coordinators see their region; global admins pick one.
class VolunteersPage extends ConsumerStatefulWidget {
  const VolunteersPage({super.key});

  @override
  ConsumerState<VolunteersPage> createState() => _VolunteersPageState();
}

class _VolunteersPageState extends ConsumerState<VolunteersPage> {
  String _tab = 'pending';

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } on AppFailure catch (e) {
      if (mounted) {
        showAppSnackBar(context, failureText(AppLocalizations.of(context), e), isError: true);
      }
    }
    if (!mounted) return;
    ref.invalidate(volunteersProvider);
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _moveTo(Volunteer v, List<Region> regions) async {
    final regionId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final r in regions)
              ListTile(
                title: Text(r.name),
                selected: r.id == v.region?.id,
                onTap: () => Navigator.pop(sheet, r.id),
              ),
          ],
        ),
      ),
    );
    if (regionId == null || !mounted) return;
    await _act(
      () => ref.read(volunteersRepositoryProvider).changeRole(
        v.id,
        role: v.isCoordinator ? 'REGION_ADMIN' : 'USER',
        regionId: regionId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final me = ref.watch(authControllerProvider).value;
    final isGlobal = me?.isAdmin == true;
    final regionId = ref.watch(selectedRegionProvider);
    final regions = isGlobal
        ? ref.watch(adminRegionsProvider).value ?? const <Region>[]
        : const <Region>[];
    final regionName = isGlobal
        ? regions.where((r) => r.id == regionId).map((r) => r.name).firstOrNull
        : me?.region?.name;
    final all = ref.watch(volunteersProvider);
    final repo = ref.read(volunteersRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.volunteers)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(volunteersProvider);
          if (regionId != null) ref.invalidate(joinCodeProvider(regionId));
          await ref.read(volunteersProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isGlobal)
              DropdownButtonFormField<int?>(
                initialValue: regionId,
                decoration: InputDecoration(labelText: l.region),
                items: [
                  DropdownMenuItem(value: null, child: Text(l.allRegions)),
                  for (final r in regions)
                    DropdownMenuItem(value: r.id, child: Text(r.name)),
                ],
                onChanged: (id) => ref.read(selectedRegionProvider.notifier).select(id),
              ),
            if (regionId != null) ...[
              const SizedBox(height: 16),
              JoinCodeCard(regionId: regionId, regionName: regionName ?? ''),
            ],
            const SizedBox(height: 16),
            all.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                failure: toAppFailure(e),
                onRetry: () => ref.invalidate(volunteersProvider),
              ),
              data: (list) {
                int count(String s) => list.where((v) => v.status == s).length;
                final shown = list.where((v) => v.status == _tab).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        for (final (value, label) in [
                          ('pending', l.tabWaiting),
                          ('active', l.tabActive),
                          ('disabled', l.tabDisabled),
                        ])
                          ButtonSegment(
                            value: value,
                            label: Text(l.tabWithCount(label, count(value))),
                          ),
                      ],
                      selected: {_tab},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _tab = s.first),
                    ),
                    const SizedBox(height: 8),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          switch (_tab) {
                            'pending' => l.noneWaiting,
                            'active' => l.noneActive,
                            _ => l.noneDisabled,
                          },
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.inkMuted),
                        ),
                      ),
                    for (final v in shown) ...[
                      _VolunteerRow(
                        volunteer: v,
                        showRegion: isGlobal && regionId == null,
                        actions: !isGlobal && (v.isCoordinator || v.isGlobalAdmin)
                            ? const []
                            : [
                          if (v.status == 'pending') ...[
                            (l.approve, () => _act(() => repo.approve(v.id))),
                            (
                              l.refuse,
                              () async {
                                if (await _confirm(l.refuseTitle(v.name), l.refuseBody, l.refuse) &&
                                    mounted) {
                                  await _act(() => repo.refuse(v.id));
                                }
                              },
                            ),
                          ],
                          if (v.status == 'active' && v.id != me?.id && !v.isGlobalAdmin)
                            (
                              l.disable,
                              () async {
                                if (await _confirm(l.disableTitle(v.name), l.disableBody, l.disable) &&
                                    mounted) {
                                  await _act(() => repo.disable(v.id));
                                }
                              },
                            ),
                          if (v.status == 'disabled')
                            (l.enable, () => _act(() => repo.enable(v.id))),
                          if (isGlobal && !v.isGlobalAdmin && v.region != null) ...[
                            (
                              v.isCoordinator ? l.makeVolunteer : l.makeCoordinator,
                              () => _act(
                                () => repo.changeRole(
                                  v.id,
                                  role: v.isCoordinator ? 'USER' : 'REGION_ADMIN',
                                  regionId: v.region!.id,
                                ),
                              ),
                            ),
                            (l.moveToRegion, () => _moveTo(v, regions)),
                          ],
                        ],
                      ),
                      const Divider(height: 1),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A hairline row: name, username and badges, actions in a menu.
class _VolunteerRow extends StatelessWidget {
  const _VolunteerRow({
    required this.volunteer,
    required this.showRegion,
    required this.actions,
  });

  final Volunteer volunteer;
  final bool showRegion;
  final List<(String, Future<void> Function())> actions;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final v = volunteer;
    final details = [
      ltr('@${v.username}'),
      if (v.isCoordinator) l.coordinator,
      if (v.joinedWithCode) l.joinedWithCode,
      if (showRegion && v.region != null) v.region!.name,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(details, style: TextStyle(color: c.inkMuted)),
      trailing: actions.isEmpty
          ? null
          : PopupMenuButton<int>(
              onSelected: (i) => actions[i].$2(),
              itemBuilder: (_) => [
                for (var i = 0; i < actions.length; i++)
                  PopupMenuItem(value: i, child: Text(actions[i].$1)),
              ],
            ),
    );
  }
}
