import 'package:flutter/material.dart';

import 'app_colors.dart';

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
    chip: AppPalette.goldSoft,
    chipInk: Color(0xFF1A2038),
    serveBand: AppPalette.serveBand,
    systemBand: Color(0xFF121A3A),
  );

  static const night = IftarColors(
    page: Color(0xFF0E1530),
    surface: Color(0xFF18213F),
    line: Color(0xFF2A3560),
    tile: Color(0xFF1F2949),
    ink: Color(0xFFF1EADB),
    inkMuted: Color(0xFFA9B0C6),
    act: AppPalette.mint,
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
    chipInk: AppPalette.goldSoft,
    serveBand: AppPalette.serveBandNight,
    systemBand: AppPalette.systemBandNight,
  );

  @override
  IftarColors copyWith({
    Color? page,
    Color? surface,
    Color? line,
    Color? tile,
    Color? ink,
    Color? inkMuted,
    Color? act,
    Color? onAct,
    Color? actInk,
    Color? actSoft,
    Color? clay,
    Color? onClay,
    Color? clayInk,
    Color? claySoft,
    Color? goldInk,
    Color? warnSoft,
    Color? chip,
    Color? chipInk,
    Color? serveBand,
    Color? systemBand,
  }) =>
      IftarColors(
        page: page ?? this.page,
        surface: surface ?? this.surface,
        line: line ?? this.line,
        tile: tile ?? this.tile,
        ink: ink ?? this.ink,
        inkMuted: inkMuted ?? this.inkMuted,
        act: act ?? this.act,
        onAct: onAct ?? this.onAct,
        actInk: actInk ?? this.actInk,
        actSoft: actSoft ?? this.actSoft,
        clay: clay ?? this.clay,
        onClay: onClay ?? this.onClay,
        clayInk: clayInk ?? this.clayInk,
        claySoft: claySoft ?? this.claySoft,
        goldInk: goldInk ?? this.goldInk,
        warnSoft: warnSoft ?? this.warnSoft,
        chip: chip ?? this.chip,
        chipInk: chipInk ?? this.chipInk,
        serveBand: serveBand ?? this.serveBand,
        systemBand: systemBand ?? this.systemBand,
      );

  @override
  IftarColors lerp(covariant IftarColors? other, double t) {
    if (other == null) return this;
    return IftarColors(
      page: Color.lerp(page, other.page, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      line: Color.lerp(line, other.line, t)!,
      tile: Color.lerp(tile, other.tile, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      act: Color.lerp(act, other.act, t)!,
      onAct: Color.lerp(onAct, other.onAct, t)!,
      actInk: Color.lerp(actInk, other.actInk, t)!,
      actSoft: Color.lerp(actSoft, other.actSoft, t)!,
      clay: Color.lerp(clay, other.clay, t)!,
      onClay: Color.lerp(onClay, other.onClay, t)!,
      clayInk: Color.lerp(clayInk, other.clayInk, t)!,
      claySoft: Color.lerp(claySoft, other.claySoft, t)!,
      goldInk: Color.lerp(goldInk, other.goldInk, t)!,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t)!,
      chip: Color.lerp(chip, other.chip, t)!,
      chipInk: Color.lerp(chipInk, other.chipInk, t)!,
      serveBand: Color.lerp(serveBand, other.serveBand, t)!,
      systemBand: Color.lerp(systemBand, other.systemBand, t)!,
    );
  }
}

extension IftarColorsContext on BuildContext {
  IftarColors get colors {
    final extension = Theme.of(this).extension<IftarColors>();
    if (extension != null) return extension;
    return Theme.of(this).brightness == Brightness.dark
        ? IftarColors.night
        : IftarColors.day;
  }
}
