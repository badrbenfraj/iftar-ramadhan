import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/theme/app_theme.dart';
import 'package:iftar_mobile/core/theme/iftar_colors.dart';

void main() {
  test('both themes carry IftarColors and the bundled font', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.extension<IftarColors>(), isNotNull);
      expect(theme.textTheme.bodyMedium?.fontFamily, AppTheme.fontFamily);
      expect(theme.colorScheme.primary, theme.extension<IftarColors>()!.act);
    }
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(AppTheme.dark().extension<IftarColors>(), IftarColors.night);
  });
}
