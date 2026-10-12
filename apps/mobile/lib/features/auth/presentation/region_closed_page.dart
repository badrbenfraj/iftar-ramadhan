import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../offline/presentation/offline_queue_controller.dart';
import 'auth_controller.dart';
import 'auth_scaffold.dart';

/// Signed in, but an admin closed the account's region. The session stays
/// open so meals served offline before the closure still sync; the router
/// leaves this page by itself once the account is moved or the region
/// reopens.
class RegionClosedPage extends ConsumerStatefulWidget {
  const RegionClosedPage({super.key});

  @override
  ConsumerState<RegionClosedPage> createState() => _RegionClosedPageState();
}

class _RegionClosedPageState extends ConsumerState<RegionClosedPage> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    ref.read(offlineQueueProvider.notifier).flush();
  }

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    try {
      await ref.read(offlineQueueProvider.notifier).flush();
      await ref.read(authControllerProvider.notifier).refreshProfile();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _logout() async {
    // Unsynced meals stay saved on this phone for the next sign-in.
    await ref.read(offlineQueueProvider.notifier).flush();
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final region = ref.watch(authControllerProvider).value?.region?.name ?? '';
    return AuthScaffold(
      title: l.regionClosedTitle,
      lead: l.regionClosedBody(isolate(region)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: _checking ? null : _checkAgain,
            child: _checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(l.checkAgain),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _checking ? null : _logout,
            child: Text(l.logout),
          ),
        ],
      ),
    );
  }
}
