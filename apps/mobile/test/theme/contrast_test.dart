import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/theme/app_colors.dart';
import 'package:iftar_mobile/core/theme/iftar_colors.dart';

import '../support/contrast.dart';

void main() {
  const white = Color(0xFFFFFFFF);
  for (final (name, c) in [('day', IftarColors.day), ('night', IftarColors.night)]) {
    group('$name: text pairs pass WCAG AA (4.5:1)', () {
      final pairs = <String, (Color, Color)>{
        'ink on page': (c.ink, c.page),
        'inkMuted on page': (c.inkMuted, c.page),
        'inkMuted on surface': (c.inkMuted, c.surface),
        'inkMuted on tile': (c.inkMuted, c.tile),
        'onAct on act': (c.onAct, c.act),
        'actInk on actSoft': (c.actInk, c.actSoft),
        'actInk on surface': (c.actInk, c.surface),
        'clayInk on claySoft': (c.clayInk, c.claySoft),
        'clay on surface': (c.clay, c.surface),
        'onClay on clay': (c.onClay, c.clay),
        'goldInk on page': (c.goldInk, c.page),
        'goldInk on warnSoft': (c.goldInk, c.warnSoft),
        'chipInk on chip': (c.chipInk, c.chip),
        'white on serveBand': (white, c.serveBand),
        'onSky on systemBand': (AppPalette.onSky, c.systemBand),
      };
      pairs.forEach((label, pair) {
        test(label, () {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        });
      });
    });
  }

  group('sky surfaces', () {
    final pairs = <String, (Color, Color)>{
      'onSky on sky': (AppPalette.onSky, AppPalette.sky),
      'onSky on horizon': (AppPalette.onSky, AppPalette.horizon),
      'onSkyMuted on skyMid': (AppPalette.onSkyMuted, AppPalette.skyMid),
      'onSkyMuted on horizon': (AppPalette.onSkyMuted, AppPalette.horizon),
      'gold on sky': (AppPalette.gold, AppPalette.sky),
      'gold on skyMid': (AppPalette.gold, AppPalette.skyMid),
      'sky on mint': (AppPalette.sky, AppPalette.mint),
      'white on pausedBand': (white, AppPalette.pausedBand),
      'white on doneBand': (white, AppPalette.doneBand),
      'onSky on waitBand': (AppPalette.onSky, AppPalette.waitBand),
    };
    pairs.forEach((label, pair) {
      test(label, () {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      });
    });
    test('gold blessing on doneBand passes AA for large text (3:1)', () {
      expect(contrast(AppPalette.gold, AppPalette.doneBand), greaterThanOrEqualTo(3));
    });
  });
}
