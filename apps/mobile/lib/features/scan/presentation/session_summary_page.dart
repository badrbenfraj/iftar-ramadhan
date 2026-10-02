import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/ramadan.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/night_sky.dart';
import '../../../l10n/app_localizations.dart';

class SessionSummary {
  const SessionSummary({
    required this.served,
    required this.singleMeals,
    required this.familyMeals,
  });

  final int served;
  final int singleMeals;
  final int familyMeals;

  int get portions => singleMeals + familyMeals * 4;
}

/// Shown when the volunteer closes the scanner after serving (spec §4.8).
class SessionSummaryPage extends ConsumerWidget {
  const SessionSummaryPage({super.key, required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final day = ramadanDay(
      ref.watch(appConfigProvider).ramadanStart,
      ref.watch(clockProvider)(),
    );
    return Scaffold(
      backgroundColor: AppPalette.sky,
      body: NightSky(
        dusk: true,
        pattern: true,
        starCount: 24,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                const Spacer(),
                Text(
                  day == null ? l.summaryKicker : '${l.summaryKicker} · ${l.ramadanDay(ltr('$day'))}',
                  style: const TextStyle(fontSize: 12.5, color: AppPalette.gold),
                ),
                Text(
                  ltr('${summary.served}'),
                  style: const TextStyle(
                    fontSize: 110,
                    fontWeight: FontWeight.w300,
                    height: 0.95,
                    color: AppPalette.onSky,
                  ),
                ),
                Text(
                  l.summaryServedByYou,
                  style: const TextStyle(fontSize: 15, color: AppPalette.onSky),
                ),
                const SizedBox(height: 6),
                Text(
                  l.summaryDetail(summary.familyMeals, summary.singleMeals, summary.portions),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppPalette.onSkyMuted),
                ),
                const SizedBox(height: 22),
                const Text(
                  blessingText,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: AppTheme.brandFont,
                    fontSize: 46,
                    color: AppPalette.gold,
                  ),
                ),
                if (l.blessingMeaning.isNotEmpty)
                  Text(
                    l.blessingMeaning,
                    style: const TextStyle(fontSize: 13, color: AppPalette.onSkyMuted),
                  ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.mint,
                    foregroundColor: AppPalette.sky,
                  ),
                  onPressed: () => context.go('/people'),
                  child: Text(l.backToPeople),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppPalette.onSky,
                    side: BorderSide(color: AppPalette.onSky.withValues(alpha: 0.35)),
                  ),
                  onPressed: () => context.go('/scan'),
                  child: Text(l.keepScanning),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
