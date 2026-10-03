import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'khatam.dart';

/// Full sky: indigo gradient, optional dusk glow at the horizon, stars,
/// crescent and pattern. Used on Welcome, Login, Splash and Summary.
class NightSky extends StatelessWidget {
  const NightSky({
    super.key,
    this.child,
    this.showMoon = true,
    this.starCount = 28,
    this.borderRadius,
    this.dusk = false,
    this.pattern = false,
  });

  final Widget? child;
  final bool showMoon;
  final int starCount;
  final BorderRadius? borderRadius;
  final bool dusk;
  final bool pattern;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppPalette.skyGradient),
        child: CustomPaint(
          painter: _SkyPainter(
            showMoon: showMoon,
            starCount: starCount,
            dusk: dusk,
            pattern: pattern,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Header band at the top of the main tabs: night gradient with the star
/// pattern, safe-area aware, ivory text and icons.
class SkyBand extends StatelessWidget {
  const SkyBand({
    super.key,
    required this.child,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 18),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppPalette.bandGradient),
      child: CustomPaint(
        painter: const KhatamPatternPainter(),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: AppPalette.onSky),
              child: IconTheme.merge(
                data: const IconThemeData(color: AppPalette.onSky),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.showMoon,
    required this.starCount,
    required this.dusk,
    required this.pattern,
  });

  final bool showMoon;
  final int starCount;
  final bool dusk;
  final bool pattern;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (dusk) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, 1.25),
            radius: 0.95,
            colors: [
              AppPalette.duskGlow.withValues(alpha: 0.42),
              AppPalette.duskGlow.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
    if (pattern) const KhatamPatternPainter().paint(canvas, size);

    // Deterministic "random" so the sky doesn't jump between rebuilds.
    final random = math.Random(1447);
    final star = Paint();
    for (var i = 0; i < starCount; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height * 0.6;
      final r = 0.6 + random.nextDouble() * 1.2;
      star.color = AppPalette.onSky.withValues(
        alpha: 0.3 + random.nextDouble() * 0.5,
      );
      canvas.drawCircle(Offset(dx, dy), r, star);
    }

    if (showMoon) {
      final radius = math.min(size.width, size.height) * 0.08;
      final center = Offset(size.width * 0.84, size.height * 0.14);
      canvas.drawCircle(
        center,
        radius * 1.4,
        Paint()
          ..color = AppPalette.gold.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
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
        Paint()..color = AppPalette.gold,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) =>
      old.showMoon != showMoon ||
      old.starCount != starCount ||
      old.dusk != dusk ||
      old.pattern != pattern;
}
