import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/night_sky.dart';

/// Landing screen (Ionic `home`): logo, Sign In, Sign Up.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.night,
      body: NightSky(
        starCount: 60,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              children: [
                const Spacer(flex: 3),
                const BrandLogo(width: 280),
                const SizedBox(height: AppSpacing.xl),
                const BrandTitle(subtitle: 'Iftar distribution for volunteers'),
                const Spacer(flex: 4),
                FilledButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Sign In'),
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.goldSoft,
                    side: const BorderSide(color: AppColors.gold, width: 1.4),
                  ),
                  onPressed: () => context.push('/register'),
                  child: const Text('Sign Up'),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while the stored session is restored at startup.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.night,
      body: NightSky(
        starCount: 60,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(width: 240),
              SizedBox(height: AppSpacing.xxl),
              SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
