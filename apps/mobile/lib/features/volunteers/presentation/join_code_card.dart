import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/info_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/volunteers_repository.dart';
import 'volunteers_controller.dart';

/// The region's code in large letters, with Share / New code / Turn off.
class JoinCodeCard extends ConsumerWidget {
  const JoinCodeCard({super.key, required this.regionId, required this.regionName});

  final int regionId;
  final String regionName;

  Future<bool> _confirm(
    BuildContext context,
    String title,
    String body,
    String action,
  ) async {
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
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
      ref.invalidate(joinCodeProvider(regionId));
    } on AppFailure catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, failureText(AppLocalizations.of(context), e), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final repo = ref.read(volunteersRepositoryProvider);
    final code = ref.watch(joinCodeProvider(regionId));
    return InfoCard(
      title: l.joinCodeTitle,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: code.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(
              failureText(l, toAppFailure(e)),
              style: TextStyle(color: c.clayInk),
            ),
            data: (value) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (value == null)
                  Text(l.joinCodeOff, style: TextStyle(color: c.inkMuted))
                else
                  SelectableText(
                    ltr(value),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (value != null)
                      FilledButton.icon(
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(l.joinCodeShare),
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(text: l.joinCodeShareMessage(regionName, value)),
                        ),
                      ),
                    OutlinedButton(
                      onPressed: () async {
                        if (value != null &&
                            !await _confirm(context, l.joinCodeNewTitle, l.joinCodeNewBody, l.joinCodeNew)) {
                          return;
                        }
                        if (!context.mounted) return;
                        await _run(context, ref, () => repo.newJoinCode(regionId));
                      },
                      child: Text(value == null ? l.joinCodeTurnOn : l.joinCodeNew),
                    ),
                    if (value != null)
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: c.clayInk),
                        onPressed: () async {
                          if (!await _confirm(context, l.joinCodeOffTitle, l.joinCodeOffBody, l.joinCodeTurnOff)) {
                            return;
                          }
                          if (!context.mounted) return;
                          await _run(context, ref, () => repo.turnOffJoinCode(regionId));
                        },
                        child: Text(l.joinCodeTurnOff),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
