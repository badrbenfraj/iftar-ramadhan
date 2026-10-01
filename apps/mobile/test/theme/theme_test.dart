import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/theme/app_theme.dart';
import 'package:iftar_mobile/core/theme/iftar_colors.dart';

import '../support/contrast.dart';

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

  test('snackbar action text color passes WCAG AA (4.5:1) on snackbar background', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final actionColor = theme.snackBarTheme.actionTextColor!;
      final bgColor = theme.snackBarTheme.backgroundColor!;
      expect(
        contrast(actionColor, bgColor),
        greaterThanOrEqualTo(4.5),
        reason:
            '${theme.brightness} snackbar action on background must pass WCAG AA',
      );
    }
  });

  test('switch off-state track outline passes WCAG 1.4.11 (3.0:1) on surface', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final colors = theme.extension<IftarColors>()!;
      // Resolve the off-state trackOutlineColor (when WidgetState.selected is not present)
      final offStateOutlineColor =
          theme.switchTheme.trackOutlineColor!.resolve({})!;
      expect(
        contrast(offStateOutlineColor, colors.surface),
        greaterThanOrEqualTo(3.0),
        reason: '${theme.brightness} switch off-state outline on surface',
      );
    }
  });

  test('copyWith changes only the specified field', () {
    const newColor = Color(0xFFFF0000);
    final modified = IftarColors.day.copyWith(page: newColor);
    expect(modified.page, newColor);
    expect(modified.surface, IftarColors.day.surface);
    expect(modified.ink, IftarColors.day.ink);
  });

  test('lerp interpolates per-field', () {
    const day = IftarColors.day;
    const night = IftarColors.night;
    final halfway = day.lerp(night, 0.5); // type inferred as IftarColors
    final expectedPage = Color.lerp(day.page, night.page, 0.5);
    expect(halfway.page, expectedPage);
  });

  test('theme text styles carry no letter-spacing (Arabic must not be spaced)', () {
    // Theme.of merges the Typography geometry (letterSpacing 0.1 to 0.5)
    // under textTheme, so check what widgets actually receive.
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      for (final geometry in [
        theme.typography.englishLike,
        theme.typography.tall,
      ]) {
        final t = ThemeData.localize(theme, geometry).textTheme;
        final styles = {
          'displayLarge': t.displayLarge,
          'displayMedium': t.displayMedium,
          'displaySmall': t.displaySmall,
          'headlineLarge': t.headlineLarge,
          'headlineMedium': t.headlineMedium,
          'headlineSmall': t.headlineSmall,
          'titleLarge': t.titleLarge,
          'titleMedium': t.titleMedium,
          'titleSmall': t.titleSmall,
          'bodyLarge': t.bodyLarge,
          'bodyMedium': t.bodyMedium,
          'bodySmall': t.bodySmall,
          'labelLarge': t.labelLarge,
          'labelMedium': t.labelMedium,
          'labelSmall': t.labelSmall,
        };
        for (final MapEntry(:key, :value) in styles.entries) {
          expect(
            value?.letterSpacing ?? 0,
            0,
            reason: '${theme.brightness} $key',
          );
        }
      }
    }
  });
}
