import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/night_sky.dart';
import '../../../l10n/app_localizations.dart';

/// Sky with the logo on top, the form on paper below (spec §4.2).
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.lead,
    this.switchLabel,
    this.onSwitch,
  });

  final String title;
  final String? lead;
  final Widget child;
  final String? switchLabel;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: c.page,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 250 + top,
              child: NightSky(
                dusk: true,
                pattern: true,
                starCount: 14,
                child: Stack(
                  children: [
                    Positioned.fill(
                      top: top,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const BrandLogo(width: 150),
                          const SizedBox(height: 6),
                          Text(
                            l.appTitle,
                            style: const TextStyle(
                              fontFamily: AppTheme.brandFont,
                              fontSize: 28,
                              height: 1.2,
                              color: AppPalette.gold,
                            ),
                          ),
                          Text(
                            l.appSubtitle,
                            style: const TextStyle(fontSize: 12.5, color: AppPalette.onSkyMuted),
                          ),
                        ],
                      ),
                    ),
                    if (Navigator.of(context).canPop())
                      PositionedDirectional(
                        start: 8,
                        top: top + 4,
                        child: BackButton(color: AppPalette.onSky, onPressed: () => Navigator.of(context).maybePop()),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                decoration: BoxDecoration(
                  color: c.page,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsetsDirectional.fromSTEB(24, 26, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: c.ink),
                    ),
                    if (lead != null) ...[
                      const SizedBox(height: 2),
                      Text(lead!, style: TextStyle(fontSize: 13, color: c.inkMuted)),
                    ],
                    const SizedBox(height: 18),
                    child,
                    if (switchLabel != null)
                      TextButton(onPressed: onSwitch, child: Text(switchLabel!)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline error above the submit button of auth forms.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.claySoft,
        borderRadius: BorderRadius.circular(AppRadii.field),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: c.clayInk),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: TextStyle(color: c.clayInk))),
        ],
      ),
    );
  }
}
