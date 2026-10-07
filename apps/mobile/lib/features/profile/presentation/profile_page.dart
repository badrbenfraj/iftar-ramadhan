import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../core/providers.dart';
import '../../../core/settings/locale_resolution.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/info_tile.dart';
import '../../../core/widgets/night_sky.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../people/presentation/people_controller.dart';
import '../../update/data/version_repository.dart';
import '../data/export_service.dart';

/// The shell's bottom bar is 72 px tall and the body extends behind it.
const _tabBarHeight = 72.0;

/// Languages in picker order (same as Welcome).
const _languageOrder = ['en', 'fr', 'ar'];

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _exporting = false;

  Future<void> _export() async {
    final l = AppLocalizations.of(context);
    setState(() => _exporting = true);
    try {
      await ref.read(peopleListProvider.notifier).refresh();
      final people = ref.read(peopleListProvider).value ?? const [];
      await ref.read(exportServiceProvider).sharePeople(people);
    } on AppFailure catch (e) {
      if (mounted) showAppSnackBar(context, failureText(l, e), isError: true);
    } catch (_) {
      if (mounted) showAppSnackBar(context, l.exportFailed, isError: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _logout() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.logoutTitle),
        content: Text(l.logoutBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.logout),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  /// The choice is already in effect; only a failure to save it is reported.
  Future<void> _report(Future<AppFailure?> saved) async {
    final failure = await saved;
    if (failure == null || !mounted) return;
    showAppSnackBar(
      context,
      failureText(AppLocalizations.of(context), failure),
      isError: true,
    );
  }

  Future<void> _pickLanguage(String current) {
    assert(_languageOrder.every(supportedLanguageCodes.contains));
    final settings = ref.read(settingsControllerProvider.notifier);
    return _showChoices(
      title: AppLocalizations.of(context).language,
      options: [
        for (final code in _languageOrder)
          // Native names, never translated.
          (label: languageNames[code]!, selected: code == current, value: code),
      ],
      onPick: (code) => _report(settings.setLocale(Locale(code))),
    );
  }

  Future<void> _pickAppearance(ThemeMode current) {
    final l = AppLocalizations.of(context);
    final settings = ref.read(settingsControllerProvider.notifier);
    return _showChoices(
      title: l.appearance,
      options: [
        for (final mode in ThemeMode.values)
          (label: _modeLabel(l, mode), selected: mode == current, value: mode),
      ],
      onPick: (mode) => _report(settings.setThemeMode(mode)),
    );
  }

  Future<void> _showChoices<T>({
    required String title,
    required List<({String label, bool selected, T value})> options,
    required void Function(T value) onPick,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              child: Text(
                title,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            for (final option in options)
              _ChoiceRow(
                label: option.label,
                selected: option.selected,
                onTap: () {
                  Navigator.pop(sheet);
                  onPick(option.value);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    ),
  );

  static String _modeLabel(AppLocalizations l, ThemeMode mode) =>
      switch (mode) {
        ThemeMode.system => l.appearanceSystem,
        ThemeMode.light => l.appearanceDay,
        ThemeMode.dark => l.appearanceNight,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const SizedBox.shrink();
    final env = ref.watch(appConfigProvider);
    final installedVersion = ref.watch(installedVersionProvider).value;
    final settings =
        ref.watch(settingsControllerProvider).value ?? const AppSettings();
    final language = Localizations.localeOf(context).languageCode;
    final regionName = user.region?.name;
    // Points toward the end of the line, so it flips in Arabic.
    final chevron = Icon(
      Directionality.of(context) == TextDirection.rtl
          ? Icons.chevron_left_rounded
          : Icons.chevron_right_rounded,
      color: c.inkMuted,
    );
    final bottomClearance =
        _tabBarHeight + MediaQuery.viewPaddingOf(context).bottom + 40;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SkyBand(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppPalette.gold,
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: AppPalette.sky,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isolate(user.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${l.ramadanKareem} · '
                        '${regionName == null ? l.noRegion : isolate(regionName)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppPalette.gold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              bottomClearance,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InfoCard(
                  title: l.profileTitle,
                  children: [
                    InfoTile(label: l.fullName, value: isolate(user.name)),
                    InfoTile(label: l.username, value: ltr(user.username)),
                    InfoTile(
                      label: l.region,
                      value: regionName == null ? null : isolate(regionName),
                    ),
                    InfoTile(
                      label: l.email,
                      value: user.email.isEmpty ? null : ltr(user.email),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                InfoCard(
                  title: l.settings,
                  children: [
                    InfoTile(
                      icon: Icons.translate_rounded,
                      label: l.language,
                      value: languageNames[language],
                      trailing: chevron,
                      onTap: () => _pickLanguage(language),
                    ),
                    InfoTile(
                      icon: Icons.dark_mode_outlined,
                      label: l.appearance,
                      value: _modeLabel(l, settings.themeMode),
                      trailing: chevron,
                      onTap: () => _pickAppearance(settings.themeMode),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                InfoCard(
                  title: l.dataSection,
                  children: [
                    InfoTile(
                      icon: Icons.table_view_rounded,
                      label: l.exportList,
                      showPlaceholder: false,
                      trailing: _exporting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            )
                          : Icon(Icons.ios_share_rounded, color: c.actInk),
                      onTap: _exporting ? null : _export,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.clay,
                    side: BorderSide(color: c.clay),
                  ),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l.logout),
                ),
                // Which build a volunteer has, when helping them update.
                if (installedVersion != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l.appVersion(installedVersion),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.inkMuted, fontSize: 12),
                  ),
                ],
                if (!env.isProduction) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '${env.environment} · ${env.apiBaseUrl}',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(color: c.inkMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One option in a choice sheet: at least 56 tall, with the current choice
/// marked by a check, a heavier weight and the selected semantics.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, color: context.colors.actInk),
            ],
          ),
        ),
      ),
    ),
  );
}
