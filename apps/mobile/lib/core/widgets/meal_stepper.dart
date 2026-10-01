import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/iftar_colors.dart';
import '../utils/formatters.dart';

/// − value + with 44 px targets; buttons disable at the bounds.
class MealStepper extends StatelessWidget {
  const MealStepper({
    super.key,
    required this.label,
    required this.caption,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9,
  });

  final String label;
  final String caption;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final style = IconButton.styleFrom(
      minimumSize: const Size.square(44),
      side: BorderSide(color: c.line),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14.5)),
                Text(caption, style: TextStyle(fontSize: 11.5, color: c.inkMuted)),
              ],
            ),
          ),
          IconButton.outlined(
            style: style,
            tooltip: l.decrease,
            icon: const Icon(Icons.remove_rounded),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 44,
            child: Semantics(
              liveRegion: true,
              label: '$label $value',
              child: Text(
                ltr('$value'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton.outlined(
            style: style,
            tooltip: l.increase,
            icon: const Icon(Icons.add_rounded),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
