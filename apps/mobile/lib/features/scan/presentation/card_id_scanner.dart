import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/qr_payload.dart';
import 'viewfinder.dart';

typedef CardIdScanner = Future<int?> Function(BuildContext context);

/// Full-screen camera that reads a blank card's ID for registration.
Future<int?> showCardIdScanner(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CardIdScannerPage(),
      ),
    );

class CardIdScannerPage extends StatefulWidget {
  const CardIdScannerPage({super.key});

  @override
  State<CardIdScannerPage> createState() => _CardIdScannerPageState();
}

class _CardIdScannerPageState extends State<CardIdScannerPage> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;
  bool _invalid = false;
  Timer? _invalidTimer;

  @override
  void dispose() {
    _invalidTimer?.cancel();
    _camera.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final payload = QrPayload.parse(barcode.rawValue);
      if (payload is PersonQr) {
        _done = true;
        Navigator.of(context).pop(payload.personId);
        return;
      }
    }
    if (!_invalid) setState(() => _invalid = true);
    // The "not a card ID" hint is a reaction, not a state: let it fade.
    _invalidTimer?.cancel();
    _invalidTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _invalid = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            errorBuilder: (context, error) => CardScannerError(
              denied: error.errorCode == MobileScannerErrorCode.permissionDenied,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
          IgnorePointer(
            child: CustomPaint(
              painter: ArchViewfinderPainter(
                _invalid ? AppPalette.gold : AppPalette.onSky,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                          foregroundColor: AppPalette.onSky,
                          minimumSize: const Size.square(48),
                        ),
                        tooltip: l.cancel,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l.cardScanTitle,
                        style: const TextStyle(
                          color: AppPalette.onSky,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppPalette.gold.withValues(alpha: 0.45)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _invalid ? l.cardInvalid : l.scanHint,
                          style: const TextStyle(color: AppPalette.onSky),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in place of the camera when it can't start.
class CardScannerError extends StatelessWidget {
  const CardScannerError({super.key, required this.denied, required this.onClose});

  /// The volunteer refused camera access (they can fix it in settings).
  final bool denied;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ColoredBox(
      color: AppPalette.sky,
      child: SafeArea(
        child: Stack(
          children: [
            PositionedDirectional(
              top: 8,
              start: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: AppPalette.onSky,
                  minimumSize: const Size.square(48),
                ),
                tooltip: l.cancel,
                icon: const Icon(Icons.close_rounded),
                onPressed: onClose,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.no_photography_outlined, size: 48, color: AppPalette.gold),
                    const SizedBox(height: 16),
                    Text(
                      denied ? l.cameraOffTitle : l.cameraUnavailableTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppPalette.onSky,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      denied ? l.cameraOffMessage : l.cameraUnavailableMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppPalette.onSkyMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
