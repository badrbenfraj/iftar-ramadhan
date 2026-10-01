import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// Outline of the 8-point star (two overlapping squares, the khatam /
/// Rub el Hizb motif): 16 vertices, outer points on [radius].
Path khatamPath(Offset center, double radius) {
  // Inner vertices sit where the squares' edges cross: r·cos45°/cos22.5°.
  final inner = radius * 0.7654;
  final path = Path();
  for (var i = 0; i < 16; i++) {
    final angle = -math.pi / 2 + i * math.pi / 8;
    final r = i.isEven ? radius : inner;
    final point = Offset(
      center.dx + r * math.cos(angle),
      center.dy + r * math.sin(angle),
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

/// Tiled star pattern, faint gold on sky surfaces (spec §3.3).
class KhatamPatternPainter extends CustomPainter {
  const KhatamPatternPainter({
    this.color = AppPalette.gold,
    this.opacity = 0.17,
    this.tile = 44,
  });

  final Color color;
  final double opacity;
  final double tile;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: opacity);
    for (var y = tile / 2; y < size.height + tile; y += tile) {
      for (var x = tile / 2; x < size.width + tile; x += tile) {
        final c = Offset(x, y);
        canvas
          ..drawPath(khatamPath(c, tile * 0.32), paint)
          ..drawCircle(c, 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant KhatamPatternPainter old) =>
      old.color != color || old.opacity != opacity || old.tile != tile;
}
