import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';

/// Bottom navigation with the center camera button sitting in a notch —
/// the Flutter equivalent of the Ionic tab bar + SVG cut-out + FAB.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (Icons.format_list_bulleted_rounded, 'People'),
    (Icons.person_add_alt_1_outlined, 'Add'),
    (Icons.insert_chart_outlined_rounded, 'Stats'),
    (Icons.person_outline_rounded, 'Profile'),
  ];

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
      // Ionic hid the tab bar and FAB while the keyboard is visible.
      floatingActionButton: keyboardOpen
          ? null
          : Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
              child: FloatingActionButton(
                heroTag: 'scan',
                tooltip: 'Scan QR card',
                elevation: 0,
                onPressed: () => context.push('/scan'),
                child: const Icon(Icons.qr_code_scanner_rounded, size: 30),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: keyboardOpen
          ? null
          : BottomAppBar(
              color: AppColors.night,
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              height: 68,
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++) ...[
                    if (i == 2) const SizedBox(width: 80),
                    Expanded(
                      child: _TabButton(
                        icon: _tabs[i].$1,
                        label: _tabs[i].$2,
                        selected: navigationShell.currentIndex == i,
                        onTap: () => _go(i),
                      ),
                    ),
                  ],
                ],
              ),
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
    final color = selected ? AppColors.gold : Colors.white70;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
