import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'khatam.dart';

enum SealKind { serve, served, problem, checking, done }

/// The 8-point star that carries a scan verdict, readable before any word
/// (spec §3.3).
class Seal extends StatelessWidget {
  const Seal(
    this.kind, {
    super.key,
    required this.semanticLabel,
    this.size = 44,
  });

  final SealKind kind;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (Color fill, IconData? glyph, Color? glyphColor) = switch (kind) {
      SealKind.serve => (Colors.white, Icons.check_rounded, AppPalette.serveBand),
      SealKind.served => (Colors.white, Icons.schedule_rounded, AppPalette.pausedBand),
      SealKind.problem => (AppPalette.gold, Icons.priority_high_rounded, AppPalette.sky),
      SealKind.done => (AppPalette.gold, Icons.check_rounded, AppPalette.doneBand),
      SealKind.checking => (AppPalette.gold, null, null),
    };
    final star = CustomPaint(
      painter: _StarPainter(color: fill, outline: kind == SealKind.checking),
      child: SizedBox.square(
        dimension: size,
        child: glyph == null
            ? null
            : Center(child: Icon(glyph, size: size * 0.42, color: glyphColor)),
      ),
    );
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: kind == SealKind.checking ? _Pulse(child: star) : star,
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter({required this.color, required this.outline});

  final Color color;
  final bool outline;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      khatamPath(size.center(Offset.zero), size.shortestSide / 2 * 0.98),
      Paint()
        ..color = color
        ..style = outline ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1.8,
    );
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) =>
      old.color != color || old.outline != outline;
}

/// Slow fade while the server is checking; still when animations are off.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller..stop()..value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 1, end: 0.45).animate(_controller),
    child: widget.child,
  );
}
