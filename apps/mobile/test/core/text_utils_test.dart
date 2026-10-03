import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/utils/formatters.dart';
import 'package:iftar_mobile/core/utils/masking.dart';
import 'package:iftar_mobile/core/utils/ramadan.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(initializeDateFormatting);
  tearDown(() => Intl.defaultLocale = null);

  test('Arabic-Indic and Persian digits become Western', () {
    expect(latinDigits('١٢:٣٠'), '12:30');
    expect(latinDigits('۰۹ مارس'), '09 مارس');
    expect(latinDigits('Mar 5, 2025'), 'Mar 5, 2025');
  });

  test('times are HH:mm with Western digits in every language', () {
    Intl.defaultLocale = 'ar';
    expect(formatTime(DateTime(2025, 3, 5, 7, 5)), '07:05');
  });

  test('dates never contain Arabic-Indic digits', () {
    for (final locale in ['ar', 'fr', 'en']) {
      Intl.defaultLocale = locale;
      final text = formatDate(DateTime(2025, 3, 5));
      expect(RegExp('[٠-٩۰-۹]').hasMatch(text), isFalse, reason: '$locale: $text');
      expect(text, contains('2025'), reason: locale);
    }
  });

  test('ltr and isolate wrap text in Unicode isolates', () {
    // ignore: text_direction_code_point_in_literal
    expect(ltr('87 / 214'), '⁦87 / 214⁩');
    // ignore: text_direction_code_point_in_literal
    expect(isolate('نجوى'), '⁨نجوى⁩');
  });

  test('CIN is masked to its last three digits', () {
    expect(maskCin('08123812'), '••••• 812');
    expect(cinLastDigits('08123812'), '812');
    expect(maskCin(null), isNull);
    expect(maskCin('12'), isNull);
  });

  test('Ramadan day counts from the configured first day', () {
    final start = DateTime(2027, 2, 8);
    expect(ramadanDay(start, DateTime(2027, 2, 8, 18)), 1);
    expect(ramadanDay(start, DateTime(2027, 2, 21, 23, 59)), 14);
    expect(ramadanDay(start, DateTime(2027, 3, 9)), 30);
    expect(ramadanDay(start, DateTime(2027, 3, 10)), isNull);
    expect(ramadanDay(start, DateTime(2027, 2, 7)), isNull);
    expect(ramadanDay(null, DateTime(2027, 2, 9)), isNull);
  });
}
