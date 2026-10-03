import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'iftar_colors.dart';

abstract final class AppTheme {
  static const fontFamily = 'ReadexPro';
  static const brandFont = 'ArefRuqaa';

  static ThemeData light() => _build(IftarColors.day, Brightness.light);
  static ThemeData dark() => _build(IftarColors.night, Brightness.dark);

  /// Zero letter-spacing on every style: Material 3's geometry would space
  /// plain Arabic text. An explicit 0 wins over the geometry that Theme.of
  /// merges in. Widgets that want Latin tracking use `labelTracking(context)`.
  static TextTheme _untracked(TextTheme t) {
    TextStyle zero(TextStyle? s) =>
        (s ?? const TextStyle()).copyWith(letterSpacing: 0);
    return t.copyWith(
      displayLarge: zero(t.displayLarge),
      displayMedium: zero(t.displayMedium),
      displaySmall: zero(t.displaySmall),
      headlineLarge: zero(t.headlineLarge),
      headlineMedium: zero(t.headlineMedium),
      headlineSmall: zero(t.headlineSmall),
      titleLarge: zero(t.titleLarge),
      titleMedium: zero(t.titleMedium),
      titleSmall: zero(t.titleSmall),
      bodyLarge: zero(t.bodyLarge),
      bodyMedium: zero(t.bodyMedium),
      bodySmall: zero(t.bodySmall),
      labelLarge: zero(t.labelLarge),
      labelMedium: zero(t.labelMedium),
      labelSmall: zero(t.labelSmall),
    );
  }

  static ThemeData _build(IftarColors c, Brightness brightness) {
    // Explicit scheme: fromSeed would derive mint-grey containers that
    // clash with the warm palette in pickers, dialogs and menus.
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.act,
      onPrimary: c.onAct,
      primaryContainer: c.actSoft,
      onPrimaryContainer: c.actInk,
      secondary: AppPalette.gold,
      onSecondary: AppPalette.sky,
      secondaryContainer: c.chip,
      onSecondaryContainer: c.chipInk,
      tertiary: AppPalette.sky,
      onTertiary: AppPalette.onSky,
      error: c.clay,
      onError: c.onClay,
      errorContainer: c.claySoft,
      onErrorContainer: c.clayInk,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.inkMuted,
      surfaceContainerLowest: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.page,
      surfaceContainerHigh: c.tile,
      surfaceContainerHighest: c.tile,
      outline: c.line,
      outlineVariant: c.line,
      inverseSurface: AppPalette.sky,
      onInverseSurface: AppPalette.onSky,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: c.page,
      extensions: [c],
    );
    final text = base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink);
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.button),
    );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: color, width: width),
        );
    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15.5,
      fontWeight: FontWeight.w500,
    );

    return base.copyWith(
      textTheme: _untracked(
        text.copyWith(
          headlineSmall: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          titleLarge: text.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
          titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.page,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: c.ink,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: c.line),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        border: border(c.line),
        enabledBorder: border(c.line),
        focusedBorder: border(c.act, 1.6),
        errorBorder: border(c.clay),
        focusedErrorBorder: border(c.clay, 1.6),
        labelStyle: TextStyle(color: c.inkMuted),
        hintStyle: TextStyle(color: c.inkMuted),
        errorStyle: TextStyle(color: c.clay),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.act,
          foregroundColor: c.onAct,
          disabledBackgroundColor: c.act.withValues(alpha: 0.4),
          disabledForegroundColor: c.onAct,
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          minimumSize: const Size.fromHeight(52),
          shape: buttonShape,
          side: BorderSide(color: c.line),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.actInk,
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppPalette.mint,
        foregroundColor: AppPalette.sky,
        shape: CircleBorder(),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.sky,
        contentTextStyle: const TextStyle(
          fontFamily: fontFamily,
          color: AppPalette.onSky,
        ),
        actionTextColor: AppPalette.mint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
          side: BorderSide(color: AppPalette.gold.withValues(alpha: 0.35)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.page,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.act),
      dividerTheme: DividerThemeData(color: c.line, space: 1),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? c.act : c.line,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected)
                  ? Colors.transparent
                  : c.inkMuted,
        ),
      ),
    );
  }
}
