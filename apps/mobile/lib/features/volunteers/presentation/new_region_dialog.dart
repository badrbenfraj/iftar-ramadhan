import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/register_page.dart';
import '../data/volunteers_repository.dart';
import 'volunteers_controller.dart';

/// Global admins add a region by name. Returns the new region, or null when
/// cancelled. Region lists are refreshed so pickers show it at once.
Future<Region?> showNewRegionDialog(BuildContext context) => showDialog<Region>(
  context: context,
  builder: (_) => const _NewRegionDialog(),
);

class _NewRegionDialog extends ConsumerStatefulWidget {
  const _NewRegionDialog();

  @override
  ConsumerState<_NewRegionDialog> createState() => _NewRegionDialogState();
}

class _NewRegionDialogState extends ConsumerState<_NewRegionDialog> {
  final _name = TextEditingController();
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
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final region = await ref
          .read(volunteersRepositoryProvider)
          .createRegion(name);
      ref
        ..invalidate(adminRegionsProvider)
        ..invalidate(regionsProvider);
      if (mounted) Navigator.pop(context, region);
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
    return AlertDialog(
      title: Text(l.newRegion),
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
              : Text(l.addRegion),
        ),
      ],
    );
  }
}
