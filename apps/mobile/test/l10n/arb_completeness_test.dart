import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _keys(Map<String, dynamic> arb) =>
    arb.keys.where((k) => !k.startsWith('@')).toSet();

void main() {
  // Arabic hides the translated meaning under Arabic text (spec §4.1, §4.6).
  const intentionallyEmpty = {
    'ar': {'hadithMeaning', 'blessingMeaning'},
  };
  final english = _arb('en');

  for (final code in ['fr', 'ar']) {
    test('$code has exactly the English keys', () {
      expect(_keys(_arb(code)), _keys(english));
    });

    test('$code has no empty strings except intentional ones', () {
      final arb = _arb(code);
      final empty = _keys(arb)
          .where((k) => (arb[k] as String).trim().isEmpty)
          .toSet();
      expect(empty, intentionallyEmpty[code] ?? <String>{});
    });
  }
}
