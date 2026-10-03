import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'khatam.dart';

/// Round-topped "Tunisian door" window with a double gold hairline and the
/// star pattern inside (Welcome, spec §4.1).
class ArchWindow extends StatelessWidget {
  const ArchWindow({
    super.key,
    required this.child,
    this.width = 212,
    this.height = 282,
  });

  final Widget child;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final outer = BorderRadius.vertical(
      top: Radius.circular(width / 2),
      bottom: const Radius.circular(10),
    );
    final inner = BorderRadius.vertical(
      top: Radius.circular(width / 2 - 7),
      bottom: const Radius.circular(6),
    );
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: outer,
            side: BorderSide(color: AppPalette.gold.withValues(alpha: 0.55)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: inner,
                side: BorderSide(
                  color: AppPalette.gold.withValues(alpha: 0.18),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: inner,
              child: CustomPaint(
                painter: const KhatamPatternPainter(opacity: 0.12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
