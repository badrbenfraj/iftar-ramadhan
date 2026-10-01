import 'package:flutter/material.dart';

import '../network/app_failure.dart';
import '../theme/app_colors.dart';

/// Centered spinner with an optional caption ("Fetching data" in Ionic).
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
              style: const TextStyle(color: AppColors.tealDeep, fontSize: 14),
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
    final (icon, title) = switch (failure) {
      NetworkFailure() => (Icons.wifi_off_rounded, 'You are offline'),
      TimeoutFailure() => (Icons.hourglass_empty_rounded, 'Server is slow'),
      ServerFailure() => (Icons.cloud_off_rounded, 'Server error'),
      UnauthorizedFailure() => (Icons.lock_outline_rounded, 'Signed out'),
      NotFoundFailure() => (Icons.search_off_rounded, 'Not found'),
      _ => (Icons.error_outline_rounded, 'Something went wrong'),
    };
    return EmptyView(
      icon: icon,
      title: title,
      message: failure.message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(
                color: AppColors.goldSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.night),
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
                style: const TextStyle(color: AppColors.inkMuted),
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

/// Snackbar helper used after actions (save, delete, confirm...).
void showAppSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.night,
      ),
    );
}
