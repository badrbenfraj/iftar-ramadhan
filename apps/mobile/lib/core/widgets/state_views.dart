import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../network/app_failure.dart';
import '../network/failure_text.dart';
import '../theme/app_colors.dart';
import '../theme/iftar_colors.dart';

/// Centered spinner with an optional caption.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox.square(
            dimension: 36,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: TextStyle(color: context.colors.actInk, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

/// Full-area error with an icon picked from the failure type and a retry.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final icon = switch (failure) {
      NetworkFailure() => Icons.wifi_off_rounded,
      TimeoutFailure() => Icons.hourglass_empty_rounded,
      ServerFailure() => Icons.cloud_off_rounded,
      UnauthorizedFailure() => Icons.lock_outline_rounded,
      NotFoundFailure() => Icons.search_off_rounded,
      _ => Icons.error_outline_rounded,
    };
    return EmptyView(
      icon: icon,
      title: failureTitle(l, failure),
      message: failureText(l, failure),
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l.tryAgain),
            ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: c.chip, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: c.chipInk),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.inkMuted),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(width: 220, child: action),
            ],
          ],
        ),
      ),
    );
  }
}

/// Snackbar after actions (save, delete, confirm...). Errors use clay.
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final c = context.colors;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: isError ? TextStyle(color: c.onClay) : null,
        ),
        backgroundColor: isError ? c.clay : null,
      ),
    );
}
