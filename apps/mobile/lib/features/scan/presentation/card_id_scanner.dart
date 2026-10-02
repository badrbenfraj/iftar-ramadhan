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

  @override
  void dispose() {
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
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _camera, onDetect: _onDetect),
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
