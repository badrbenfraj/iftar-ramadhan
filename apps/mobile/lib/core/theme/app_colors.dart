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

  /// Viewfinder frame for "already served": a clay stop that reads on the sky.
  static const clayFrame = Color(0xFFE8957A);

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
