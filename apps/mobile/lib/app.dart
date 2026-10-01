import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'core/router/app_router.dart';
import 'core/settings/locale_resolution.dart';
import 'core/settings/settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

class IftarApp extends ConsumerWidget {
  const IftarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
