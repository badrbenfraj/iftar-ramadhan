import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/settings/locale_resolution.dart';

void main() {
  test('a saved choice wins over the device', () {
    expect(
      resolveAppLocale(const Locale('fr'), const [Locale('en', 'US')]),
      const Locale('fr'),
    );
  });

  test('first supported device language is used', () {
    expect(
      resolveAppLocale(null, const [Locale('de'), Locale('fr', 'TN')]),
      const Locale('fr'),
    );
  });

  test('falls back to Arabic when nothing is supported', () {
    expect(resolveAppLocale(null, const [Locale('de')]), const Locale('ar'));
    expect(resolveAppLocale(null, null), const Locale('ar'));
    expect(resolveAppLocale(const Locale('it'), null), const Locale('ar'));
  });

  test('a regional saved choice keeps only its language', () {
    expect(
      resolveAppLocale(const Locale('fr', 'TN'), null),
      const Locale('fr'),
    );
  });

  test('an empty device list falls back to Arabic', () {
    expect(resolveAppLocale(null, const []), const Locale('ar'));
  });
}
