import 'package:flutter/services.dart';
import 'package:iftar_mobile/core/theme/app_theme.dart';

Future<void>? _loaded;

/// Loads the bundled fonts so layout tests measure real glyphs instead of
/// flutter_test's Ahem boxes. Safe to call more than once.
Future<void> loadAppFonts() => _loaded ??= _load();

Future<void> _load() async {
  Future<void> family(String name, List<String> assets) {
    final loader = FontLoader(name);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    return loader.load();
  }

  // Family names and files as declared in pubspec.yaml.
  await family(AppTheme.fontFamily, [
    for (final weight in [300, 400, 500, 600, 700])
      'assets/fonts/ReadexPro-$weight.ttf',
  ]);
  await family(AppTheme.brandFont, [
    'assets/fonts/ArefRuqaa-400.ttf',
    'assets/fonts/ArefRuqaa-700.ttf',
  ]);
}
