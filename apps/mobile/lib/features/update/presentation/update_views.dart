import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/night_sky.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import 'update_controller.dart';

/// Replaces the whole app while the installed version is below the server's
/// `minimumVersion`. There is deliberately no way past it but updating.
class ForceUpdatePage extends ConsumerWidget {
  const ForceUpdatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppPalette.sky,
        body: NightSky(
          starCount: 40,
          dusk: true,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandLogo(width: 168),
                    const SizedBox(height: 28),
                    const Icon(Icons.system_update_rounded, size: 40, color: AppPalette.gold),
                    const SizedBox(height: 12),
                    Text(
                      l.updateRequiredTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppTheme.brandFont,
                        fontSize: 28,
                        height: 1.2,
                        color: AppPalette.gold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l.updateRequiredBody,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.5, color: AppPalette.onSky),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.mint,
                          foregroundColor: AppPalette.sky,
                        ),
                        onPressed: () => _openDownloadPage(context, ref),
                        icon: const Icon(Icons.download_rounded),
                        label: Text(l.updateNow),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The optional "new version" prompt, offered once per app run.
Future<void> showOptionalUpdateDialog(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final version = ref.read(updateControllerProvider).info.latestVersion ?? '';
  final update = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.system_update_rounded),
      title: Text(l.updateAvailableTitle),
      content: Text(l.updateAvailableBody(version)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.updateLater),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l.updateNow),
        ),
      ],
    ),
  );
  // The shell may be gone (signed out meanwhile): ref is unusable then.
  if (!context.mounted) return;
  ref.read(updateControllerProvider.notifier).dismissPrompt();
  if (update == true) await _openDownloadPage(context, ref);
}

Future<void> _openDownloadPage(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final opened = await ref
      .read(updateControllerProvider.notifier)
      .openDownloadPage();
  if (!opened && context.mounted) {
    showAppSnackBar(context, l.updateOpenFailed, isError: true);
  }
}

/// Offers the optional update once the volunteer is on the main screens
/// (not on the splash, whose redirect would close the dialog).
class UpdatePrompter extends ConsumerStatefulWidget {
  const UpdatePrompter({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdatePrompter> createState() => _UpdatePrompterState();
}

class _UpdatePrompterState extends ConsumerState<UpdatePrompter> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    if (_showing || !mounted) return;
    if (!ref.read(updateControllerProvider).showOptionalPrompt) return;
    _showing = true;
    await showOptionalUpdateDialog(context, ref);
    _showing = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(updateControllerProvider, (_, next) {
      if (next.showOptionalPrompt) _maybePrompt();
    });
    return widget.child;
  }
}
