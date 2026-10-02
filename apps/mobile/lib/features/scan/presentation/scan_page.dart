import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import 'scan_controller.dart';
import 'scan_result_panel.dart';

/// Continuous QR scanner optimized for a volunteer serving a queue:
/// the camera stays open, each card resolves to a clear result, and one tap
/// confirms and returns to scanning.
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
    detectionTimeoutMs: 300,
  );

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null) {
        ref.read(scanControllerProvider.notifier).onDetected(raw);
        return;
      }
    }
  }

  Future<void> _manualEntry() async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter ID manually'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Identifier',
            prefixIcon: Icon(Icons.pin_outlined),
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Look up'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (id != null && id.trim().isNotEmpty) {
      await ref.read(scanControllerProvider.notifier).submitManual(id);
    }
  }

  void _hapticsFor(ScanStatus status) {
    switch (status) {
      case ScanReady():
        HapticFeedback.selectionClick();
      case ScanConfirmed():
        HapticFeedback.mediumImpact();
      case ScanAlreadyTaken():
        HapticFeedback.heavyImpact();
        HapticFeedback.vibrate();
      case ScanInvalidCode() || ScanNotFound() || ScanFailed():
        HapticFeedback.vibrate();
      case ScanIdle() ||
          ScanLookingUp() ||
          ScanIdentifying() ||
          ScanConfirming():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      scanControllerProvider.select((s) => s.status),
      (_, next) => _hapticsFor(next),
    );
    final scan = ref.watch(scanControllerProvider);
    final frameColor = switch (scan.status) {
      ScanReady() || ScanConfirming() => AppColors.teal,
      ScanConfirmed() => AppColors.success,
      ScanAlreadyTaken() => AppColors.danger,
      ScanInvalidCode() || ScanNotFound() || ScanFailed() => AppColors.warning,
      _ => AppColors.gold,
    };

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            errorBuilder: (context, error) =>
                _CameraUnavailable(error: error, onManualEntry: _manualEntry),
          ),
          // Without a camera, the frame and the "align the card" hint would
          // only obscure the fallback message; manual entry takes over.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _camera,
            builder: (context, camera, _) {
              final cameraAvailable = camera.error == null;
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (cameraAvailable)
                    IgnorePointer(child: _ScanFrame(color: frameColor)),
                  SafeArea(
                    child: Column(
                      children: [
                        _TopBar(
                          camera: _camera,
                          servedCount: scan.servedCount,
                          onClose: () => context.canPop()
                              ? context.pop()
                              : context.go('/people'),
                          onManualEntry: _manualEntry,
                        ),
                        const Spacer(),
                        if (cameraAvailable || scan.status is! ScanIdle)
                          ScanResultPanel(
                            status: scan.status,
                            onManualEntry: _manualEntry,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.camera,
    required this.servedCount,
    required this.onClose,
    required this.onManualEntry,
  });

  final MobileScannerController camera;
  final int servedCount;
  final VoidCallback onClose;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          _RoundIcon(
            icon: Icons.close_rounded,
            tooltip: 'Close scanner',
            onPressed: onClose,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scan Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Served this session: $servedCount',
                  style: const TextStyle(
                    color: AppColors.goldSoft,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: camera,
            builder: (context, value, _) {
              if (value.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final on = value.torchState == TorchState.on;
              return _RoundIcon(
                icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                tooltip: on ? 'Turn torch off' : 'Turn torch on',
                active: on,
                onPressed: camera.toggleTorch,
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          _RoundIcon(
            icon: Icons.keyboard_alt_outlined,
            tooltip: 'Enter ID manually',
            onPressed: onManualEntry,
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: active
            ? AppColors.gold
            : Colors.black.withValues(alpha: 0.45),
        foregroundColor: active ? AppColors.night : Colors.white,
        minimumSize: const Size.square(48),
      ),
      icon: Icon(icon),
    );
  }
}

/// Dimmed backdrop with a clear square and lantern-gold corner brackets.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: const Duration(milliseconds: 250),
      builder: (context, animated, _) =>
          CustomPaint(painter: _FramePainter(animated ?? color)),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.68;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.38),
      width: side,
      height: side,
    );
    final window = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(window),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 34.0;
    const r = 24.0;
    final corners = [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ];
    for (final (p, dx, dy) in corners) {
      final path = Path()
        ..moveTo(p.dx, p.dy + dy * (r + len))
        ..lineTo(p.dx, p.dy + dy * r)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + dx * r, p.dy)
        ..lineTo(p.dx + dx * (r + len), p.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter old) => old.color != color;
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error, required this.onManualEntry});

  final MobileScannerException error;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: AppColors.night,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 48,
                color: AppColors.gold,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                denied ? 'Camera access is off' : 'Camera unavailable',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                denied
                    ? 'Allow camera access for this app in your phone settings '
                          'to scan QR cards. You can still enter IDs manually.'
                    : 'The camera could not be started. You can still enter '
                          'IDs manually.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: onManualEntry,
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('Enter ID manually'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
