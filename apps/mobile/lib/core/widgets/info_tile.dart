import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// "Label: value" row, the building block of the Ionic detail screens.
class InfoTile extends StatelessWidget {
  const InfoTile({
    super.key,
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    this.icon,
    this.showPlaceholder = true,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Show a dash when [value] is empty (off for action rows).
  final bool showPlaceholder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppColors.goldDeep),
              const SizedBox(width: AppSpacing.md),
            ],
            Text(
              label,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                (value == null || value!.isEmpty)
                    ? (showPlaceholder ? '—' : '')
                    : value!,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppSpacing.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// White rounded card grouping [InfoTile]s with dividers.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.children, this.title});

  final List<Widget> children;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                title!.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.goldDeep,
                  fontSize: 12,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: AppSpacing.lg),
            children[i],
          ],
        ],
      ),
    );
  }
}
