import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/iftar_colors.dart';
import '../core/widgets/state_views.dart';
import '../features/offline/presentation/offline_queue_controller.dart';
import '../features/update/presentation/update_views.dart';
import '../l10n/app_localizations.dart';

/// Tabs on a floating sky pill with side margins; a gold rule tops the
/// active tab. The mint scan button rises through the pill's top edge in a
/// cream ring (user decision, 2026-10-10: variant 2).
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // "{n} offline meals synced" (spec 2B §5.2), once per sync.
    ref.listen(offlineQueueProvider.select((s) => s.lastSynced), (prev, next) {
      if (next == null || identical(prev, next)) return;
      showAppSnackBar(
        context,
        AppLocalizations.of(context).offlineSynced(next.count),
      );
    });
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      body: UpdatePrompter(child: navigationShell),
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

  /// The pill itself, without the margins and the room for the scan button.
  static const pillKey = ValueKey('app-bottom-nav-pill');

  static const _pillHeight = 64.0;

  /// How far the scan button rises above the pill.
  static const _raise = 16.0;

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
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    // The margins stay transparent to taps, so the page under them still
    // scrolls and responds; extendBody pads the page by this whole height.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md + bottomInset,
      ),
      child: SizedBox(
        height: _raise + _pillHeight,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned.fill(
              top: _raise,
              child: DecoratedBox(
                key: pillKey,
                decoration: BoxDecoration(
                  color: AppPalette.sky,
                  borderRadius: BorderRadius.circular(_pillHeight / 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.skyTop.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
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
              ),
            ),
            if (onScan != null) ScanButton(onPressed: onScan!),
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
    final color = selected ? AppPalette.gold : AppPalette.onSkyMuted;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Gold rule on the pill's top edge, grown in for the active tab.
            Positioned(
              top: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: selected ? 24 : 0,
                height: 3,
                decoration: const BoxDecoration(
                  color: AppPalette.gold,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(3),
                  ),
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
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
          ],
        ),
      ),
    );
  }
}

/// 56 px mint circle in a gold ring, set in a ring of the page color so it
/// reads as cut out of the pill it rises through.
class ScanButton extends StatelessWidget {
  const ScanButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).navScan;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.page,
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppPalette.gold,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: _ScanCore(label: label, onPressed: onPressed),
          ),
        ),
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
              child: Icon(
                Icons.qr_code_scanner_rounded,
                size: 28,
                color: AppPalette.sky,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
