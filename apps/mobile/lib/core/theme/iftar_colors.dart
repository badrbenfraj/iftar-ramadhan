import 'package:flutter/material.dart';

/// Semantic colors that differ between the day and night themes
/// (spec §3.1). Read them with `context.colors`.
@immutable
class IftarColors extends ThemeExtension<IftarColors> {
  const IftarColors({
    required this.page,
    required this.surface,
    required this.line,
    required this.tile,
    required this.ink,
    required this.inkMuted,
    required this.act,
    required this.onAct,
    required this.actInk,
    required this.actSoft,
    required this.clay,
    required this.onClay,
    required this.clayInk,
    required this.claySoft,
    required this.goldInk,
    required this.warnSoft,
    required this.chip,
    required this.chipInk,
    required this.serveBand,
    required this.systemBand,
  });

  final Color page;
  final Color surface;
  final Color line;
  final Color tile;
  final Color ink;
  final Color inkMuted;

  /// Primary actions on light surfaces ("serve or act").
  final Color act;
  final Color onAct;
  final Color actInk;
  final Color actSoft;

  /// "Already served" and errors. Never alarm red.
  final Color clay;
  final Color onClay;
  final Color clayInk;
  final Color claySoft;

  /// Gold-colored text on light surfaces.
  final Color goldInk;
  final Color warnSoft;

  /// ID chips.
  final Color chip;
  final Color chipInk;

  /// Scan verdict bands that change with the theme.
  final Color serveBand;
  final Color systemBand;

  static const day = IftarColors(
    page: Color(0xFFF6F1E7),
    surface: Color(0xFFFFFCF6),
    line: Color(0xFFE3D9C6),
    tile: Color(0xFFF1EBDF),
    ink: Color(0xFF1A2038),
    inkMuted: Color(0xFF5D6377),
    act: Color(0xFF0D6B62),
    onAct: Color(0xFFFFFFFF),
    actInk: Color(0xFF0A5049),
    actSoft: Color(0xFFDCEEE8),
    clay: Color(0xFFA8432A),
    onClay: Color(0xFFFFFFFF),
    clayInk: Color(0xFF7E2F1D),
    claySoft: Color(0xFFF5E2D8),
    goldInk: Color(0xFF86621A),
    warnSoft: Color(0xFFF3EBD6),
    chip: Color(0xFFF1E3BF),
    chipInk: Color(0xFF1A2038),
    serveBand: Color(0xFF0D6B62),
    systemBand: Color(0xFF121A3A),
  );

  static const night = IftarColors(
    page: Color(0xFF0E1530),
    surface: Color(0xFF18213F),
    line: Color(0xFF2A3560),
    tile: Color(0xFF1F2949),
    ink: Color(0xFFF1EADB),
    inkMuted: Color(0xFFA9B0C6),
    act: Color(0xFF43CEBB),
    onAct: Color(0xFF121A3A),
    actInk: Color(0xFF86E3D4),
    actSoft: Color(0xFF123E48),
    clay: Color(0xFFE8957A),
    onClay: Color(0xFF121A3A),
    clayInk: Color(0xFFF0A68D),
    claySoft: Color(0xFF3A2632),
    goldInk: Color(0xFFD6A645),
    warnSoft: Color(0xFF2B2A33),
    chip: Color(0xFF2A3055),
    chipInk: Color(0xFFF1E3BF),
    serveBand: Color(0xFF0F7A70),
    systemBand: Color(0xFF2A3563),
  );

  @override
  IftarColors copyWith() => this;

  /// Day and night are distinct palettes; snapping halfway is enough.
  @override
  IftarColors lerp(covariant IftarColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension IftarColorsContext on BuildContext {
  IftarColors get colors =>
      Theme.of(this).extension<IftarColors>() ?? IftarColors.day;
}
