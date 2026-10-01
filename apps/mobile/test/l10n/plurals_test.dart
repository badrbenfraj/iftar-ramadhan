import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/l10n/app_localizations.dart';

void main() {
  // intl's French plural rule maps 0 to `one`, so a literal `=1{1 …}` branch
  // would print "1 portion" for a count of zero.
  group('French plurals', () {
    final fr = lookupAppLocalizations(const Locale('fr'));

    test('portions: zero and one are singular, two is plural', () {
      expect(fr.portions(0), '0 portion');
      expect(fr.portions(1), '1 portion');
      expect(fr.portions(2), '2 portions');
    });

    test('a count of zero is never printed as "1 …"', () {
      final atZero = {
        'mealSingleCount': fr.mealSingleCount(0),
        'mealFamilyCount': fr.mealFamilyCount(0),
        'handsOverEachEvening': fr.handsOverEachEvening(0),
        'personSavedHandOver': fr.personSavedHandOver('Najwa', 0),
        'servedLine': fr.servedLine('Najwa', 0),
      };
      atZero.forEach((key, text) {
        expect(text, contains('0'), reason: key);
        expect(text, isNot(contains('1 ')), reason: key);
      });
    });
  });

  test('English portions(0) says 0', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.portions(0), contains('0'));
  });
}
