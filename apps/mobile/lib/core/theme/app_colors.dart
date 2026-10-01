import 'package:flutter/material.dart';

/// Design tokens — "Ramadan night".
///
/// Continuity with the Ionic app: the teal primary (#43CEBB and its
/// shade/tint), the calligraphy logo and the Arabic status words are kept.
/// New: a deep-indigo night sky, lantern gold accents and warm ivory surfaces.
abstract final class AppColors {
  // Brand (unchanged from the Ionic theme)
  static const teal = Color(0xFF43CEBB);
  static const tealShade = Color(0xFF3BB5A5);
  static const tealTint = Color(0xFF56D3C2);
  static const tealDeep = Color(0xFF1F8A7C); // text/icons on light surfaces

  // Ramadan night
  static const night = Color(0xFF0E1A3A);
  static const nightMid = Color(0xFF16275A);
  static const nightGlow = Color(0xFF26407F);

  // Lantern gold
  static const gold = Color(0xFFE2B44F);
  static const goldSoft = Color(0xFFF3DEA6);
  static const goldDeep = Color(0xFFB8862B);

  // Surfaces
  static const ivory = Color(0xFFF7F4EC); // page background (was #F5F5F3)
  static const surface = Colors.white;
  static const outline = Color(0xFFE6E0D2);

  // Text
  static const ink = Color(0xFF1B2236);
  static const inkMuted = Color(0xFF69708A);

  // Status
  static const success = Color(0xFF1E9E6A); // may collect / confirmed
  static const successSoft = Color(0xFFDDF4EA);
  static const danger = Color(0xFFEB445A); // Ionic danger, unchanged
  static const dangerSoft = Color(0xFFFCE3E6);
  static const warning = Color(0xFFE08A1E);
  static const warningSoft = Color(0xFFFCEBD3);

  static const nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [night, nightMid, nightGlow],
    stops: [0, 0.6, 1],
  );
}

/// Spacing scale (4-pt grid) and radii shared by all screens.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const gutter = 20.0;
}

abstract final class AppRadii {
  static const pill = 50.0; // Ionic auth inputs and buttons
  static const card = 20.0;
  static const field = 16.0;
  static const chip = 12.0;
}
