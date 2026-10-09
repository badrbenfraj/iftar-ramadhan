import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import 'auth_scaffold.dart';

/// After registering without a join code, or signing in before approval
/// (security spec §8).
class PendingPage extends StatelessWidget {
  const PendingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.pendingTitle,
      lead: l.pendingBody,
      child: FilledButton(
        onPressed: () => context.go('/login'),
        child: Text(l.backToSignIn),
      ),
    );
  }
}
