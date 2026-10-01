import 'package:flutter/material.dart';

import '../../features/people/domain/fasting_person.dart';
import '../../l10n/app_localizations.dart';
import '../theme/iftar_colors.dart';
import '../utils/formatters.dart';

/// Tunisian pickup words, kept in every language (spec §5).
abstract final class MealStatusWords {
  static const taken = 'خذا';
  static const notTaken = 'ما خذاش';
}

/// "○ ما خذاش" or "✓ خذا 18:12": an icon and a word, never color alone.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.person, this.now});

  final FastingPerson person;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final taken = person.isMealTakenToday(now);
    final at = person.lastTakenMeal;
    final text = taken
        ? '${isolate(MealStatusWords.taken)}'
              '${at == null ? '' : ' ${ltr(formatTime(at))}'}'
        : isolate(MealStatusWords.notTaken);
    final fg = taken ? c.clayInk : c.actInk;
    return Semantics(
      label: taken ? l.servedTooltip : l.notServedTooltip,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(7, 2, 9, 2),
        decoration: BoxDecoration(
          color: taken ? c.claySoft : c.actSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              taken ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
              size: 13,
              color: fg,
            ),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
