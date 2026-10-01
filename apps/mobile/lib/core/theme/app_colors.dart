import 'package:flutter/material.dart';

/// "Maghrib light" sky and band colors, identical in both themes.
/// Theme-dependent colors live in `IftarColors` (`context.colors`).
abstract final class AppPalette {
  static const skyTop = Color(0xFF0E1530);
  static const sky = Color(0xFF121A3A);
  static const skyMid = Color(0xFF1D2754);
  static const horizon = Color(0xFF3A3566);
  static const horizonLow = Color(0xFF5A4560);
  static const duskGlow = Color(0xFFE8A86B);
  static const onSky = Color(0xFFF3EBDD);
  static const onSkyMuted = Color(0xFFA8AEC8);
  static const gold = Color(0xFFD6A645);
  static const goldSoft = Color(0xFFF1E3BF);
  static const mint = Color(0xFF43CEBB);

  // Scan verdict bands. White text, except the gold blessing on doneBand.
  static const serveBand = Color(0xFF0D6B62);
  static const serveBandNight = Color(0xFF0F7A70);
  static const doneBand = Color(0xFF0A5049);
  static const pausedBand = Color(0xFFA8432A);
  static const systemBandNight = Color(0xFF2A3563);
  static const waitBand = Color(0xFF2A3360);

  /// Full-screen sky: Welcome, Login header, Summary.
  static const skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyTop, skyMid, horizon, horizonLow],
    stops: [0, 0.55, 0.86, 1],
  );

  /// Header bands on the main tabs.
  static const bandGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [skyTop, skyMid],
  );
}

/// Legacy names from the first Flutter theme, re-pointed at the new
/// palette so unmigrated screens keep compiling. Removed in Task 20; don't
/// add new uses.
abstract final class AppColors {
  static const teal = Color(0xFF0D6B62);
  static const tealShade = Color(0xFF0A5049);
  static const tealTint = Color(0xFFDCEEE8);
  static const tealDeep = Color(0xFF0A5049);
  static const night = AppPalette.sky;
  static const nightMid = AppPalette.skyMid;
  static const nightGlow = AppPalette.horizon;
  static const gold = AppPalette.gold;
  static const goldSoft = AppPalette.goldSoft;
  static const goldDeep = Color(0xFF86621A);
  static const ivory = Color(0xFFF6F1E7);
  static const surface = Color(0xFFFFFCF6);
  static const outline = Color(0xFFE3D9C6);
  static const ink = Color(0xFF1A2038);
  static const inkMuted = Color(0xFF5D6377);
  static const success = Color(0xFF0D6B62);
  static const successSoft = Color(0xFFDCEEE8);
  static const danger = Color(0xFFA8432A);
  static const dangerSoft = Color(0xFFF5E2D8);
  static const warning = Color(0xFF86621A);
  static const warningSoft = Color(0xFFF3EBD6);
  static const nightGradient = AppPalette.skyGradient;
}

/// Spacing scale (4-pt grid) shared by all screens.
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
  static const pill = 50.0;
  static const card = 16.0;
  static const sheet = 26.0;
  static const button = 14.0;
  static const field = 14.0;
  static const chip = 10.0;
}
