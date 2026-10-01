import 'package:intl/intl.dart';

/// Arabic-Indic (٠–٩) and Persian (۰–۹) digits → 0–9. The app shows
/// Western digits in every language (spec §5).
String latinDigits(String text) {
  final out = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      out.writeCharCode(0x30 + rune - 0x0660);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      out.writeCharCode(0x30 + rune - 0x06F0);
    } else {
      out.writeCharCode(rune);
    }
  }
  return out.toString();
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Localized "Mar 3, 2025" (follows `Intl.defaultLocale`).
String formatDate(DateTime date) =>
    latinDigits(DateFormat.yMMMd().format(date));

/// "18:42", always 24-hour with Western digits.
String formatTime(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';

String formatDateTime(DateTime date) =>
    '${formatDate(date)} · ${formatTime(date)}';

/// `YYYY-MM-DD`, the day format sent to the statistics API.
String formatDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${_two(date.month)}-'
    '${_two(date.day)}';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Wraps user text (often Arabic names) in a first-strong isolate
/// so it doesn't reorder the surrounding sentence.
// ignore: text_direction_code_point_in_literal, text_direction_code_point_in_comment
String isolate(String text) => '⁨$text⁩';

/// Wraps IDs, times, CIN fragments and counts in a left-to-right isolate,
/// so "87 / 214" or "#0142" never flip inside Arabic text.
// ignore: text_direction_code_point_in_literal, text_direction_code_point_in_comment
String ltr(String text) => '⁦$text⁩';
