import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../l10n/app_localizations.dart';

/// Tabs on a sky-colored bar, with the mint scan button in the middle of the
/// bar. It sits inside the bar, not raised above it, so it never covers the
/// page or its sheets (user decision, 2026-10-02).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: navigationShell,
      extendBody: true,
      // Hidden while typing, as in the Ionic app.
      bottomNavigationBar: keyboardOpen
          ? null
          : AppBottomNav(
              currentIndex: navigationShell.currentIndex,
              onSelect: _go,
              onScan: () => context.push('/scan'),
            ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    this.onScan,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  /// Opens the scanner from the button in the middle of the bar. Null leaves
  /// the middle slot empty.
  final VoidCallback? onScan;

  static const _icons = [
    Icons.format_list_bulleted_rounded,
    Icons.person_add_alt_1_outlined,
    Icons.insert_chart_outlined_rounded,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = [l.navPeople, l.navAdd, l.navStats, l.navProfile];
    return BottomAppBar(
      color: AppPalette.sky,
      height: 72,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i == 2)
              SizedBox(
                width: 84,
                child: onScan == null
                    ? null
                    // Raised 16 px: enough presence, never over the page.
                    : OverflowBox(
                        maxHeight: double.infinity,
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: const Offset(0, -16),
                          child: ScanButton(onPressed: onScan!),
                        ),
                      ),
              ),
            Expanded(
              child: _TabButton(
                icon: _icons[i],
                label: labels[i],
                selected: currentIndex == i,
                onTap: () => onSelect(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppPalette.gold : AppPalette.onSkyMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 56 px mint circle set in a thin sky ring with a soft mint glow, raised a
/// little above the bar; no gold ring (spec §4.11).
class ScanButton extends StatelessWidget {
  const ScanButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).navScan;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.sky,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppPalette.mint.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: _ScanCore(label: label, onPressed: onPressed),
      ),
    );
  }
}

class _ScanCore extends StatelessWidget {
  const _ScanCore({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Material(
          color: AppPalette.mint,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: const SizedBox.square(
              dimension: 56,
              child: Icon(Icons.qr_code_scanner_rounded, size: 28, color: AppPalette.sky),
            ),
          ),
        ),
      ),
    );
  }
}
