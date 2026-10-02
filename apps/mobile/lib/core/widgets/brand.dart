import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// "Whoever gives iftar to a fasting person shares in their reward."
/// Shown in Arabic in every language; its meaning is translated (spec §4.1).
const hadithText = 'من فطّر صائماً كان له مثل أجره';

/// "May God accept it", said after each confirmed iftar (spec §4.6, §4.8).
const blessingText = 'تقبّل الله';

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
