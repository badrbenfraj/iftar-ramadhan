import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Deep-indigo Ramadan sky with a crescent moon and scattered stars, drawn in
/// code (no image assets). Used behind the welcome/auth heroes and headers.
class NightSky extends StatelessWidget {
  const NightSky({
    super.key,
    this.child,
    this.showMoon = true,
    this.starCount = 28,
    this.borderRadius,
  });

  final Widget? child;
  final bool showMoon;
  final int starCount;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.nightGradient),
        child: CustomPaint(
          painter: _SkyPainter(showMoon: showMoon, starCount: starCount),
          child: child,
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.showMoon, required this.starCount});

  final bool showMoon;
  final int starCount;

  @override
  void paint(Canvas canvas, Size size) {
    // Deterministic "random" so the sky doesn't jump between rebuilds.
    final random = math.Random(1447);
    final starPaint = Paint()..color = AppColors.goldSoft;
    for (var i = 0; i < starCount; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height * 0.85;
      final r = 0.6 + random.nextDouble() * 1.4;
      starPaint.color = AppColors.goldSoft.withValues(
        alpha: 0.35 + random.nextDouble() * 0.6,
      );
      if (i % 7 == 0) {
        _sparkle(canvas, Offset(dx, dy), r * 2.6, starPaint);
      } else {
        canvas.drawCircle(Offset(dx, dy), r, starPaint);
      }
    }

    if (showMoon) {
      final radius = math.min(size.width, size.height) * 0.11;
      final center = Offset(size.width * 0.84, size.height * 0.2);
      final glow = Paint()
        ..color = AppColors.gold.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
      canvas.drawCircle(center, radius * 1.3, glow);

      final moon = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));
      final bite = Path()
        ..addOval(
          Rect.fromCircle(
            center: center.translate(radius * 0.45, -radius * 0.25),
            radius: radius * 0.88,
          ),
        );
      canvas.drawPath(
        Path.combine(PathOperation.difference, moon, bite),
        Paint()..color = AppColors.gold,
      );
    }
  }

  void _sparkle(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) =>
      old.showMoon != showMoon || old.starCount != starCount;
}
