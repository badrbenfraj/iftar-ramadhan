import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/volunteers_repository.dart';
import 'volunteers_controller.dart';

/// Global admins name a new region, or rename [region]. Returns the saved
/// name, or null when cancelled. Region lists are refreshed so pickers show
/// the change at once.
Future<String?> showRegionNameDialog(BuildContext context, {Region? region}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _RegionNameDialog(region: region),
    );

class _RegionNameDialog extends ConsumerStatefulWidget {
  const _RegionNameDialog({this.region});

  final Region? region;

  @override
  ConsumerState<_RegionNameDialog> createState() => _RegionNameDialogState();
}

class _RegionNameDialogState extends ConsumerState<_RegionNameDialog> {
  late final _name = TextEditingController(text: widget.region?.name);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = l.nameRequired);
      return;
    }
    final region = widget.region;
    if (name == region?.name) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(volunteersRepositoryProvider);
      if (region == null) {
        await repo.createRegion(name);
      } else {
        await repo.renameRegion(region.id, name);
        // The admin's own region may be the one renamed.
        await ref.read(authControllerProvider.notifier).refreshProfile();
      }
      ref.invalidate(adminRegionsProvider);
      if (mounted) Navigator.pop(context, name);
    } on AppFailure catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = failureText(l, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final renaming = widget.region != null;
    return AlertDialog(
      title: Text(renaming ? l.renameRegion : l.newRegion),
      content: TextField(
        controller: _name,
        autofocus: true,
        enabled: !_saving,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: l.regionName, errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(renaming ? l.save : l.addRegion),
        ),
      ],
    );
  }
}
