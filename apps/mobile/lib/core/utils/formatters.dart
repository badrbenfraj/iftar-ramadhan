import 'package:intl/intl.dart';

/// Same shape as Angular's default `date` pipe: "Mar 3, 2025".
String formatDate(DateTime date) => DateFormat.yMMMd().format(date);

String formatTime(DateTime date) => DateFormat.Hm().format(date);

String formatDateTime(DateTime date) =>
    '${formatDate(date)} · ${formatTime(date)}';

/// `YYYY-MM-DD`, the day format sent to the statistics API.
String formatDayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Wraps user text (often Arabic) in Unicode first-strong isolates so it
/// doesn't reorder the surrounding English sentence ("... deleted.").
String isolate(String text) => '\u2068$text\u2069';
