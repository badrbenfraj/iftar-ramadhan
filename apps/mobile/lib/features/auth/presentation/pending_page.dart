import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_scaffold.dart';

/// After signing up in a region that approves new volunteers, or signing in
/// before approval (security spec §8).
class PendingPage extends StatelessWidget {
  const PendingPage({super.key, this.regionName});

  /// Known right after sign-up; null when coming from the sign-in screen.
  final String? regionName;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.pendingTitle,
      lead: regionName == null
          ? l.pendingBody
          : l.pendingBodyRegion(isolate(regionName!)),
      child: FilledButton(
        onPressed: () => context.go('/login'),
        child: Text(l.backToSignIn),
      ),
    );
  }
}
