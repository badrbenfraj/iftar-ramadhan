import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/failure_text.dart';
import '../../../core/settings/locale_resolution.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/arch_window.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/night_sky.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';

/// Landing screen: always night (spec §4.1).
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppPalette.sky,
      body: NightSky(
        starCount: 40,
        dusk: true,
        child: SafeArea(
          // Fills the screen at normal sizes; scrolls when large text makes
          // the page taller than the screen (spec §8).
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        const _LanguagePicker(),
                        const Spacer(flex: 2),
                        ArchWindow(
                          // The window is fixed; large text shrinks to fit.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 170,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const BrandLogo(width: 168),
                                  const SizedBox(height: 12),
                                  const Text(
                                    hadithText,
                                    textAlign: TextAlign.center,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      fontFamily: AppTheme.brandFont,
                                      fontSize: 17,
                                      height: 1.5,
                                      color: AppPalette.onSky,
                                    ),
                                  ),
                                  if (l.hadithMeaning.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      l.hadithMeaning,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppPalette.onSkyMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.appTitle,
                          style: const TextStyle(
                            fontFamily: AppTheme.brandFont,
                            fontSize: 32,
                            height: 1.2,
                            color: AppPalette.gold,
                          ),
                        ),
                        Text(
                          l.appSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppPalette.onSkyMuted,
                          ),
                        ),
                        const Spacer(flex: 3),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.mint,
                            foregroundColor: AppPalette.sky,
                          ),
                          onPressed: () => context.push('/login'),
                          child: Text(l.signIn),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppPalette.onSky,
                            side: BorderSide(
                              color: AppPalette.onSky.withValues(alpha: 0.35),
                            ),
                          ),
                          onPressed: () => context.push('/register'),
                          child: Text(l.createVolunteerAccount),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three pills; the language is the first choice a volunteer makes.
class _LanguagePicker extends ConsumerWidget {
  const _LanguagePicker();

  static const _order = ['en', 'fr', 'ar'];

  /// The language is already in effect; only a failure to save it is
  /// reported (as in Profile).
  static Future<void> _pick(BuildContext context, WidgetRef ref, String code) async {
    final failure = await ref
        .read(settingsControllerProvider.notifier)
        .setLocale(Locale(code));
    if (failure == null || !context.mounted) return;
    showAppSnackBar(
      context,
      failureText(AppLocalizations.of(context), failure),
      isError: true,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(_order.every(supportedLanguageCodes.contains));
    final current = Localizations.localeOf(context).languageCode;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final code in _order)
          Semantics(
            button: true,
            selected: code == current,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => _pick(context, ref, code),
              child: Container(
                // Material's 48 px touch target (spec: at least 44).
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: code == current
                      ? AppPalette.gold
                      : AppPalette.onSky.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: code == current
                        ? AppPalette.gold
                        : AppPalette.onSky.withValues(alpha: 0.22),
                  ),
                ),
                // Centers the label in the taller pill without widening it.
                child: Align(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    languageNames[code]!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: code == current ? AppPalette.sky : AppPalette.onSky,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shown while the stored session is restored at startup.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppPalette.sky,
      body: NightSky(
        starCount: 40,
        dusk: true,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(width: 220),
              SizedBox(height: 32),
              SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppPalette.gold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
