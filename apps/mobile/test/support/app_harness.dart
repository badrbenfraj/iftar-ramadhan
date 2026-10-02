import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:iftar_mobile/core/theme/app_theme.dart';
import 'package:iftar_mobile/l10n/app_localizations.dart';

/// A themed, localized app around [child] for widget tests.
Widget localizedApp(
  Widget child, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
  bool night = false,
}) => ProviderScope(
  overrides: overrides,
  retry: (_, _) => null,
  child: MaterialApp(
    theme: night ? AppTheme.dark() : AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  ),
);

/// A themed, localized app driven by [router], for navigation tests.
Widget localizedRouterApp(
  GoRouter router, {
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) => ProviderScope(
  overrides: overrides,
  retry: (_, _) => null,
  child: MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
  ),
);

/// Strings for assertions, e.g. `en.signIn`.
final en = lookupAppLocalizations(const Locale('en'));
final ar = lookupAppLocalizations(const Locale('ar'));
