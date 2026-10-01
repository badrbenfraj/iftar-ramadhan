import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The "رمضان كريم" calligraphy from the Ionic app, tinted for its background
/// (gold on the night sky, indigo on ivory).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.onDark = true, this.width = 260});

  final bool onDark;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ramadan Kareem',
      image: true,
      child: Image.asset(
        'assets/images/ramadan.png',
        width: width,
        fit: BoxFit.contain,
        color: onDark ? AppColors.gold : AppColors.night,
        colorBlendMode: BlendMode.srcIn,
      ),
    );
  }
}

/// App name in Arabic with an English subtitle.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.onDark = true, this.subtitle});

  final bool onDark;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = onDark ? AppColors.goldSoft : AppColors.night;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'إفطار صائم',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ],
    );
  }
}
