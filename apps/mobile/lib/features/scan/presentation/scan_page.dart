import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/network/connectivity.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../offline/presentation/offline_queue_controller.dart';
import '../../people/domain/fasting_person.dart';
import '../../people/presentation/people_controller.dart';
import '../../people/presentation/people_filter.dart';
import 'scan_controller.dart';
import 'scan_result_panel.dart';
import 'session_summary_page.dart';
import 'viewfinder.dart';

/// Continuous QR scanner for a volunteer serving a queue: the camera stays
/// open, each card resolves to a clear verdict, and one tap confirms.
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key, @visibleForTesting this.camera});

  /// Replaces the real camera in tests; the page disposes it.
  final MobileScannerController? camera;

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  late final MobileScannerController _camera =
      widget.camera ??
      MobileScannerController(
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
    // The camera keeps running under Find (and any other page on top); a card
    // read there must not replace what the volunteer is choosing.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null) {
        ref.read(scanControllerProvider.notifier).onDetected(raw);
        return;
      }
    }
  }

  Future<void> _findWithoutCard() async {
    if (!ref.read(scanControllerProvider).acceptsScans) return;
    final id = await context.push<int>('/find');
    // A card may have been read while the list was open; its pending
    // decision must not be replaced by the person found there.
    if (id != null && mounted && ref.read(scanControllerProvider).acceptsScans) {
      await ref.read(scanControllerProvider.notifier).pickWithoutCard(id);
    }
  }

  void _close() {
    final scan = ref.read(scanControllerProvider);
    if (scan.servedCount > 0) {
      context.pushReplacement(
        '/summary',
        extra: SessionSummary(
          served: scan.servedCount,
          singleMeals: scan.singleMeals,
          familyMeals: scan.familyMeals,
        ),
      );
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/people');
    }
  }

  /// Only "ready" (contact edits) and "confirmed" (Undo in flight) are
  /// re-created in place; every other change is news worth a buzz.
  static bool _sameVerdict(ScanStatus a, ScanStatus b) =>
      (a is ScanReady && b is ScanReady && a.person.id == b.person.id) ||
      (a is ScanConfirmed && b is ScanConfirmed && a.person.id == b.person.id);

  void _hapticsFor(ScanStatus status) {
    switch (status) {
      case ScanReady():
        HapticFeedback.selectionClick();
      case ScanConfirmed():
        HapticFeedback.mediumImpact();
      case ScanAlreadyTaken():
        HapticFeedback.heavyImpact();
        HapticFeedback.vibrate();
      case ScanInvalidCode() ||
          ScanNotFound() ||
          ScanFailed() ||
          ScanUnverified() ||
          ScanNotOnPhone():
        HapticFeedback.vibrate();
      case ScanIdle() || ScanLookingUp() || ScanIdentifying() || ScanConfirming():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      scanControllerProvider.select((s) => s.status),
      (prev, next) {
        // Editing the contact re-creates ScanReady for the same person.
        if (prev != null && _sameVerdict(prev, next)) return;
        _hapticsFor(next);
      },
    );
    ref.listen(scanControllerProvider.select((s) => s.notice), (prev, next) {
      if (next == null || identical(prev, next)) return;
      final l = AppLocalizations.of(context);
      showAppSnackBar(
        context,
        switch (next.kind) {
          ScanNoticeKind.undone => l.undone(isolate(next.name ?? '')),
          ScanNoticeKind.undoFailed => l.undoFailed,
          ScanNoticeKind.undoTooLate => l.undoTooLate,
          ScanNoticeKind.undoNeedsConnection => l.undoNeedsConnection,
        },
        isError: next.kind != ScanNoticeKind.undone,
      );
    });
    final l = AppLocalizations.of(context);
    final scan = ref.watch(scanControllerProvider);
    final now = ref.watch(clockProvider)();
    // Watching the list also keeps it loaded for instant identify.
    final people = ref.watch(peopleListProvider).value ?? const <FastingPerson>[];
    final servedTonight = countPeople(people, now).served;
    final userId = ref.watch(authControllerProvider.select((a) => a.value?.id));
    final toSync = ref.watch(
      offlineQueueProvider.select((s) => s.pendingFor(userId).length),
    );
    final frameColor = switch (scan.status) {
      ScanReady() || ScanConfirming() => AppPalette.mint,
      ScanAlreadyTaken() => AppPalette.clayFrame,
      ScanIdentifying() ||
      ScanLookingUp() ||
      ScanInvalidCode() ||
      ScanFailed() ||
      ScanUnverified() ||
      ScanNotOnPhone() => AppPalette.gold,
      ScanNotFound() => AppPalette.onSkyMuted,
      _ => AppPalette.onSky,
    };

    // Leaving mid-confirmation would drop the answer: Close and back wait
    // until it arrives.
    final confirming = scan.status is ScanConfirming;
    // Android back after serving shows the summary like the close button.
    return PopScope(
      canPop: scan.servedCount == 0 && !confirming,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !confirming) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _camera,
              onDetect: _onDetect,
              // The fallback is drawn below, from this page's own build, so its
              // "find" action follows the scan state.
              errorBuilder: (context, error) => const SizedBox.expand(),
            ),
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _camera,
              builder: (context, camera, _) {
                final available = camera.error == null;
                final showHint = scan.status is ScanIdle || scan.status is ScanConfirmed;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (camera.error case final error?)
                      _CameraUnavailable(
                        error: error,
                        // Disabled, not hidden, while someone is pending.
                        onFind: scan.acceptsScans ? _findWithoutCard : null,
                      ),
                    if (available)
                      IgnorePointer(
                        child: TweenAnimationBuilder<Color?>(
                          tween: ColorTween(end: frameColor),
                          duration: const Duration(milliseconds: 250),
                          builder: (_, color, _) => CustomPaint(
                            painter: ArchViewfinderPainter(color ?? frameColor),
                          ),
                        ),
                      ),
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          _TopBar(
                            camera: _camera,
                            servedTonight: servedTonight,
                            toSync: toSync,
                            onClose: confirming ? null : _close,
                            // Disabled, not hidden, while someone is pending.
                            onFind: available && scan.acceptsScans ? _findWithoutCard : null,
                            showFind: available,
                            offline: !ref.watch(connectivityProvider),
                          ),
                          // The sheet takes what it needs of the space below the
                          // top bar and scrolls inside itself beyond that.
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (available && showHint)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _HintPill(l.scanHint),
                                    ),
                                  if (available || scan.status is! ScanIdle)
                                    Flexible(
                                      child: ScanResultPanel(
                                        status: scan.status,
                                        onFindWithoutCard: _findWithoutCard,
                                      ),
                                    ),
                                ],
                              ),
                            ),
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
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.camera,
    required this.servedTonight,
    required this.toSync,
    required this.onClose,
    required this.onFind,
    required this.showFind,
    required this.offline,
  });

  final MobileScannerController camera;
  final int servedTonight;
  final int toSync;

  /// Null while a confirmation is in flight.
  final VoidCallback? onClose;

  /// "Find someone without a card"; null while someone is pending.
  final VoidCallback? onFind;

  /// Hidden when the camera is off: that screen has its own Find button.
  final bool showFind;

  final bool offline;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _RoundIcon(icon: Icons.close_rounded, tooltip: l.closeScanner, onPressed: onClose),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l.scanTitle,
                  style: const TextStyle(color: AppPalette.onSky, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                Text(
                  toSync > 0
                      ? '${l.servedTonight(servedTonight)} · ${l.toSync(toSync)}'
                      : l.servedTonight(servedTonight),
                  style: const TextStyle(color: AppPalette.gold, fontSize: 11.5),
                ),
              ],
            ),
          ),
          if (offline) ...[
            Tooltip(
              message: l.offlineIndicator,
              child: const Icon(Icons.cloud_off_rounded, color: AppPalette.gold),
            ),
            const SizedBox(width: 8),
          ],
          if (showFind) ...[
            _RoundIcon(icon: Icons.person_search_rounded, tooltip: l.findNoCard, onPressed: onFind),
            const SizedBox(width: 8),
          ],
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: camera,
            builder: (context, value, _) {
              if (value.torchState == TorchState.unavailable) return const SizedBox.shrink();
              final on = value.torchState == TorchState.on;
              return _RoundIcon(
                icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                tooltip: on ? l.torchOff : l.torchOn,
                active: on,
                onPressed: camera.toggleTorch,
              );
            },
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
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      // On is an onSky outline, not a gold fill (spec §3.1).
      backgroundColor: Colors.black.withValues(alpha: 0.4),
      foregroundColor: AppPalette.onSky,
      minimumSize: const Size.square(44),
      side: BorderSide(
        color: AppPalette.onSky.withValues(alpha: active ? 0.9 : 0.18),
        width: active ? 2 : 1,
      ),
    ),
    icon: Icon(icon),
  );
}

class _HintPill extends StatelessWidget {
  const _HintPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppPalette.gold.withValues(alpha: 0.45)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.nightlight_round, size: 14, color: AppPalette.gold),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text, style: const TextStyle(color: AppPalette.onSky, fontSize: 12.5)),
          ),
        ],
      ),
    ),
  );
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({required this.error, required this.onFind});

  final MobileScannerException error;
  final VoidCallback? onFind;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: AppPalette.sky,
      child: Center(
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
                style: const TextStyle(color: AppPalette.onSky, fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                denied ? l.cameraOffMessage : l.cameraUnavailableMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.onSky.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.mint,
                  foregroundColor: AppPalette.sky,
                ),
                onPressed: onFind,
                icon: const Icon(Icons.search_rounded),
                label: Text(l.findNoCard),
              ),
              if (denied) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton.icon(
                  onPressed: openAppSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(l.cameraOpenSettings),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
