import 'package:flutter/widgets.dart';

/// Languages the app ships, in picker order.
const supportedLanguageCodes = ['ar', 'fr', 'en'];

/// Native names, never translated.
const languageNames = {'ar': 'العربية', 'fr': 'Français', 'en': 'English'};

/// The volunteer's choice wins, then the first supported device language,
/// then Arabic (spec §1, confirmed at review).
Locale resolveAppLocale(Locale? chosen, Iterable<Locale>? device) {
  if (chosen != null && supportedLanguageCodes.contains(chosen.languageCode)) {
    return Locale(chosen.languageCode);
  }
  for (final locale in device ?? const <Locale>[]) {
    if (supportedLanguageCodes.contains(locale.languageCode)) {
      return Locale(locale.languageCode);
    }
  }
  return const Locale('ar');
}
