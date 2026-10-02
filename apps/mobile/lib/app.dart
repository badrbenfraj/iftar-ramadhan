import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'core/router/app_router.dart';
import 'core/settings/locale_resolution.dart';
import 'core/settings/settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/startup_permissions.dart';
import 'features/people/presentation/people_controller.dart';
import 'l10n/app_localizations.dart';

class IftarApp extends ConsumerStatefulWidget {
  const IftarApp({super.key});

  @override
  ConsumerState<IftarApp> createState() => _IftarAppState();
}

class _IftarAppState extends ConsumerState<IftarApp> {
  // The phone is never told the day changed; coming back to the foreground
  // is when a list loaded on an earlier day gets reloaded.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
    // After the first frame, so the system dialog appears over the app UI.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => requestStartupPermissions(),
    );
  }

  void _onResume() {
    if (!ref.exists(peopleListProvider)) return;
    unawaited(ref.read(peopleListProvider.notifier).reloadIfDayChanged());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(settingsControllerProvider).value ?? const AppSettings();
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: (device, _) =>
          resolveAppLocale(null, device),
      builder: (context, child) {
        // Dates follow the UI language; digits stay Western (formatters.dart).
        Intl.defaultLocale = Localizations.localeOf(context).languageCode;
        return child!;
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}
