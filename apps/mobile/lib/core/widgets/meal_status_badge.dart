import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The Tunisian-Arabic pickup status from the Ionic app:
/// `خذا` (took it) / `ما خذاش` (hasn't taken it).
///
/// Colors are intentionally semantic for the volunteer's decision:
/// already taken → red (stop), not taken → green (serve). The Ionic app used
/// the reverse, which made "already collected" look like a go-ahead.
class MealStatusBadge extends StatelessWidget {
  const MealStatusBadge({
    super.key,
    required this.takenToday,
    this.large = false,
  });

  final bool takenToday;
  final bool large;

  static const takenLabel = 'خذا';
  static const notTakenLabel = 'ما خذاش';

  @override
  Widget build(BuildContext context) {
    final color = takenToday ? AppColors.danger : AppColors.success;
    return Semantics(
      label: takenToday ? 'Meal already taken today' : 'Meal not taken today',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 16 : 12,
          vertical: large ? 6 : 3,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          takenToday ? takenLabel : notTakenLabel,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: large ? 16 : 13,
          ),
        ),
      ),
    );
  }
}
