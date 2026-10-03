import 'package:flutter/material.dart';

import '../../features/people/domain/fasting_person.dart';
import '../../l10n/app_localizations.dart';
import '../theme/iftar_colors.dart';
import '../utils/formatters.dart';

/// "What to hand over": the largest thing on the scan sheet (spec §4.6).
class HandOverTiles extends StatelessWidget {
  const HandOverTiles({super.key, required this.person});

  final FastingPerson person;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _Tile(
            count: person.familyMeal,
            label: l.familyMeal,
            caption: person.familyMeal > 0
                ? l.portions(person.familyMeal * 4)
                : l.none,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Tile(
            count: person.singleMeal,
            label: l.singleMeal,
            caption: person.singleMeal > 0 ? l.portions(person.singleMeal) : l.none,
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.count, required this.label, required this.caption});

  final int count;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // A zero tile is quieter through its hollow fill, outline and muted
    // number. Text is never faded with opacity: it must stay AA (spec §8).
    final zero = count == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: zero ? c.surface : c.tile,
        border: Border.all(color: zero ? c.line : Colors.transparent),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            ltr('$count'),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              height: 1,
              color: zero ? c.inkMuted : c.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.3, color: c.ink),
                ),
                Text(caption, style: TextStyle(fontSize: 11, color: c.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
