import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../l10n/app_localizations.dart';

/// Tabs on a sky-colored bar, with the raised mint scan button docked in the
/// middle (spec §4.11).
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
      floatingActionButton: keyboardOpen
          ? null
          : ScanButton(onPressed: () => context.push('/scan')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: keyboardOpen
          ? null
          : AppBottomNav(
              currentIndex: navigationShell.currentIndex,
              onSelect: _go,
            ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

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
            if (i == 2) const SizedBox(width: 84),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 62 px mint circle in a 6 px sky ring; no gold ring (spec §4.11).
class ScanButton extends StatelessWidget {
  const ScanButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).navScan;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(color: AppPalette.sky, shape: BoxShape.circle),
      child: Tooltip(
        message: label,
        child: Material(
          color: AppPalette.mint,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: const SizedBox.square(
              dimension: 62,
              child: Icon(Icons.qr_code_scanner_rounded, size: 28, color: AppPalette.sky),
            ),
          ),
        ),
      ),
    );
  }
}
