import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/night_sky.dart';

/// Shared layout for login/register: night-sky header with the logo and a
/// curved ivory sheet holding the form (Ionic: logo above pill inputs).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.switchLabel,
    this.onSwitch,
  });

  final String title;
  final Widget child;
  final String? switchLabel;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: NightSky(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(36),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  topInset,
                  AppSpacing.sm,
                  AppSpacing.xxl,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (Navigator.of(context).canPop())
                          const BackButton(color: AppColors.goldSoft),
                        const Spacer(),
                        if (switchLabel != null)
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.goldSoft,
                            ),
                            onPressed: onSwitch,
                            child: Text(switchLabel!),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const BrandLogo(width: 220),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.goldSoft,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(30, 32, 30, 32),
            sliver: SliverToBoxAdapter(child: child),
          ),
        ],
      ),
    );
  }
}

/// Inline error shown above the submit button of auth forms.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
