import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/region_picker.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/user.dart';
import '../data/volunteers_repository.dart';
import 'region_name_dialog.dart';
import 'volunteers_controller.dart';

/// Profile → Regions (global admins): add, rename, offline serving, close,
/// reopen, and delete a region nobody uses yet.
class RegionsPage extends ConsumerStatefulWidget {
  const RegionsPage({super.key});

  @override
  ConsumerState<RegionsPage> createState() => _RegionsPageState();
}

class _RegionsPageState extends ConsumerState<RegionsPage> {
  VolunteersRepository get _repo => ref.read(volunteersRepositoryProvider);

  /// Runs [action], then refreshes every region list. Returns false on error
  /// (already shown).
  Future<bool> _act(Future<void> Function() action, {String? done}) async {
    final l = AppLocalizations.of(context);
    try {
      await action();
    } on AppFailure catch (e) {
      if (mounted) showAppSnackBar(context, failureText(l, e), isError: true);
      return false;
    } finally {
      ref.invalidate(adminRegionsProvider);
    }
    if (mounted && done != null) showAppSnackBar(context, done);
    return true;
  }

  Future<bool> _confirm(
    String title,
    String body,
    String action, {
    bool destructive = false,
  }) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialog).colorScheme.error,
                    foregroundColor: Theme.of(dialog).colorScheme.onError,
                  )
                : null,
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _rename(Region region) async {
    final name = await showRegionNameDialog(context, region: region);
    if (name != null && mounted) {
      showAppSnackBar(
        context,
        AppLocalizations.of(context).regionRenamed(isolate(name)),
      );
    }
  }

  Future<void> _close(Region region, List<Region> regions) async {
    final l = AppLocalizations.of(context);
    final result = await showDialog<({int? moveTo})>(
      context: context,
      builder: (_) => _CloseRegionDialog(
        region: region,
        openRegions: regions
            .where((r) => r.active && r.id != region.id)
            .toList(),
      ),
    );
    if (result == null || !mounted) return;
    await _act(
      () => _repo.closeRegion(region.id, moveUsersTo: result.moveTo),
      done: l.regionClosedDone(isolate(region.name)),
    );
  }

  Future<void> _reopen(Region region) async {
    final l = AppLocalizations.of(context);
    if (!await _confirm(
          l.reopenRegionTitle(isolate(region.name)),
          l.reopenRegionBody,
          l.reopenRegion,
        ) ||
        !mounted) {
      return;
    }
    await _act(
      () => _repo.reopenRegion(region.id),
      done: l.regionReopened(isolate(region.name)),
    );
  }

  Future<void> _delete(Region region, List<Region> regions) async {
    final l = AppLocalizations.of(context);
    final RegionUsage usage;
    try {
      usage = await _repo.regionUsage(region.id);
    } on AppFailure catch (e) {
      if (mounted) showAppSnackBar(context, failureText(l, e), isError: true);
      return;
    }
    if (!mounted) return;
    if (!usage.isEmpty) {
      // In use: deleting would lose history; offer closing instead.
      final closeInstead = await _confirm(
        l.regionInUseTitle(isolate(region.name)),
        '${l.errRegionInUse}\n\n'
        '${l.regionUsage(usage.users, usage.people, usage.meals)}',
        l.closeRegion,
      );
      if (closeInstead && region.active && mounted) {
        await _close(region, regions);
      }
      return;
    }
    if (!await _confirm(
          l.deleteRegionTitle(isolate(region.name)),
          l.deleteRegionBody,
          l.delete,
          destructive: true,
        ) ||
        !mounted) {
      return;
    }
    await _act(
      () => _repo.deleteRegion(region.id),
      done: l.regionDeleted(isolate(region.name)),
    );
  }

  Future<void> _showActions(Region region, List<Region> regions) {
    final l = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    void then(VoidCallback action) {
      Navigator.pop(context);
      action();
    }

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
                child: Text(
                  isolate(region.name),
                  style: Theme.of(sheet).textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l.renameRegion),
                onTap: () => then(() => _rename(region)),
              ),
              if (region.active) ...[
                _OfflineServingTile(
                  region: region,
                  onChanged: (allowed) => _act(
                    () => _repo.setOfflineServing(region.id, allowed: allowed),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: Text(l.closeRegion),
                  onTap: () => then(() => _close(region, regions)),
                ),
              ] else
                ListTile(
                  leading: const Icon(Icons.lock_open_rounded),
                  title: Text(l.reopenRegion),
                  onTap: () => then(() => _reopen(region)),
                ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: error),
                title: Text(l.delete, style: TextStyle(color: error)),
                onTap: () => then(() => _delete(region, regions)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final regions = ref.watch(adminRegionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.regions)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final name = await showRegionNameDialog(context);
          if (name != null && context.mounted) {
            showAppSnackBar(context, l.regionAdded(isolate(name)));
          }
        },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(l.newRegion),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(adminRegionsProvider.future),
        child: regions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            failure: toAppFailure(e),
            onRetry: () => ref.invalidate(adminRegionsProvider),
          ),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 96),
            children: [
              for (final r in list)
                ListTile(
                  leading: Icon(
                    r.active
                        ? Icons.location_on_outlined
                        : Icons.lock_outline_rounded,
                    color: r.active ? null : c.inkMuted,
                  ),
                  title: Text(
                    isolate(r.name),
                    style: r.active ? null : TextStyle(color: c.inkMuted),
                  ),
                  trailing: r.active
                      ? null
                      : _ClosedChip(label: l.regionClosedTag),
                  onTap: () => _showActions(r, list),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosedChip extends StatelessWidget {
  const _ClosedChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: c.inkMuted),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: c.inkMuted, fontSize: 12)),
    );
  }
}

/// Switch that reflects the change at once and reverts if saving fails.
class _OfflineServingTile extends StatefulWidget {
  const _OfflineServingTile({required this.region, required this.onChanged});

  final Region region;
  final Future<bool> Function(bool allowed) onChanged;

  @override
  State<_OfflineServingTile> createState() => _OfflineServingTileState();
}

class _OfflineServingTileState extends State<_OfflineServingTile> {
  late bool _allowed = widget.region.allowOfflineServing;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SwitchListTile(
      secondary: const Icon(Icons.cloud_off_rounded),
      title: Text(l.offlineServing),
      subtitle: Text(l.offlineServingHint),
      value: _allowed,
      onChanged: (value) async {
        setState(() => _allowed = value);
        final ok = await widget.onChanged(value);
        if (!ok && mounted) setState(() => _allowed = !value);
      },
    );
  }
}

/// Confirms closing [region]: what it holds, and where to move its users.
/// Returns null when cancelled.
class _CloseRegionDialog extends ConsumerStatefulWidget {
  const _CloseRegionDialog({required this.region, required this.openRegions});

  final Region region;
  final List<Region> openRegions;

  @override
  ConsumerState<_CloseRegionDialog> createState() => _CloseRegionDialogState();
}

class _CloseRegionDialogState extends ConsumerState<_CloseRegionDialog> {
  late final Future<RegionUsage> _usage = ref
      .read(volunteersRepositoryProvider)
      .regionUsage(widget.region.id);
  int? _moveTo;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l.closeRegionTitle(isolate(widget.region.name))),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.closeRegionBody),
            const SizedBox(height: 12),
            FutureBuilder<RegionUsage>(
              future: _usage,
              builder: (context, snapshot) {
                final usage = snapshot.data;
                if (usage == null) {
                  return snapshot.hasError
                      ? const SizedBox.shrink()
                      : const LinearProgressIndicator();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.regionUsage(usage.users, usage.people, usage.meals),
                      style: TextStyle(color: c.inkMuted),
                    ),
                    if (usage.users > 0 && widget.openRegions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      RegionPickerField(
                        regions: widget.openRegions,
                        value: _moveTo,
                        allLabel: l.dontMoveUsers,
                        decoration: InputDecoration(labelText: l.moveUsersTo),
                        onChanged: (id) => setState(() => _moveTo = id),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, (moveTo: _moveTo)),
          child: Text(l.closeRegion),
        ),
      ],
    );
  }
}
