import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Dimmed camera with a round-topped arch window and a gold diamond at the
/// apex (spec §4.6). [color] reflects the scan state.
class ArchViewfinderPainter extends CustomPainter {
  ArchViewfinderPainter(this.color);

  final Color color;

  static Rect windowFor(Size size) {
    final width = size.shortestSide * 0.42;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.36),
      width: width,
      height: width * 1.1,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final window = windowFor(size);
    final arch = RRect.fromRectAndCorners(
      window,
      topLeft: Radius.circular(window.width / 2),
      topRight: Radius.circular(window.width / 2),
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );
    canvas
      ..drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(Offset.zero & size),
          Path()..addRRect(arch),
        ),
        Paint()..color = const Color(0x7A060914),
      )
      ..drawRRect(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = color,
      );
    final apex = Offset(window.center.dx, window.top);
    const d = 4.5;
    canvas.drawPath(
      Path()
        ..moveTo(apex.dx, apex.dy - d)
        ..lineTo(apex.dx + d, apex.dy)
        ..lineTo(apex.dx, apex.dy + d)
        ..lineTo(apex.dx - d, apex.dy)
        ..close(),
      Paint()..color = AppPalette.gold,
    );
  }

  @override
  bool shouldRepaint(covariant ArchViewfinderPainter old) => old.color != color;
}
