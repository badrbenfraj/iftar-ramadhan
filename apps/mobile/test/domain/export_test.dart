import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/profile/data/export_service.dart';

import '../support/fakes.dart';

void main() {
  test('the export file is named after the list and the moment, never FlutterExcel', () {
    expect(
      exportFileName(DateTime(2027, 2, 8, 19, 5)),
      'fasting-persons-2027-02-08-19_05.xlsx',
    );
  });

  test('the workbook holds one row per person under a header', () {
    final bytes = buildPeopleWorkbook([person(101), person(102)], DateTime(2027, 2, 8, 19));
    final book = Excel.decodeBytes(bytes);
    expect(book.tables.keys, ['Fasting persons']);
    expect(book.tables['Fasting persons']!.maxRows, 3);
  });
}
