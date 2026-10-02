import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/l10n/app_localizations.dart';

void main() {
  // Without CFBundleLocalizations iOS reports only the development region to
  // Flutter, so the app would never follow a French or Arabic device.
  test('Info.plist declares every language the app is translated into', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final match = RegExp(
      r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(match, isNotNull, reason: 'CFBundleLocalizations is missing');
    final declared = RegExp(
      r'<string>(\w+)</string>',
    ).allMatches(match!.group(1)!).map((m) => m.group(1)!).toSet();
    final supported = AppLocalizations.supportedLocales
        .map((l) => l.languageCode)
        .toSet();
    expect(declared, supported);
  });
}
