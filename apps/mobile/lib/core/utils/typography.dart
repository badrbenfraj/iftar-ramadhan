import 'package:flutter/widgets.dart';

/// Letter-spacing for small labels; 0 for Arabic, whose joins break
/// when letters are spaced (spec §3.2).
double labelTracking(BuildContext context, [double tracking = 1.2]) =>
    Localizations.localeOf(context).languageCode == 'ar' ? 0 : tracking;
