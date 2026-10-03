import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/formatters.dart';
import '../../people/domain/fasting_person.dart';

const _xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Builds the "fasting persons list" spreadsheet (Ionic: xlsx export).
List<int> buildPeopleWorkbook(List<FastingPerson> people, DateTime now) {
  final excel = Excel.createExcel();
  const sheetName = 'Fasting persons';
  excel.rename(excel.getDefaultSheet() ?? 'Sheet1', sheetName);
  final sheet = excel[sheetName];

  sheet.appendRow([
    for (final h in [
      'ID',
      'CIN',
      'First name',
      'Last name',
      'Phone',
      'Single meals',
      'Family meals',
      'Comment',
      'Last meal',
      'Meals taken',
      'Taken today',
    ])
      TextCellValue(h),
  ]);
  for (final p in people) {
    sheet.appendRow([
      IntCellValue(p.id),
      TextCellValue(p.cin ?? ''),
      TextCellValue(p.firstName),
      TextCellValue(p.lastName),
      TextCellValue(p.phone ?? ''),
      IntCellValue(p.singleMeal),
      IntCellValue(p.familyMeal),
      TextCellValue(p.comment ?? ''),
      TextCellValue(
        p.lastTakenMeal == null ? '' : formatDateTime(p.lastTakenMeal!),
      ),
      IntCellValue(p.takenMeals.length),
      TextCellValue(p.isMealTakenToday(now) ? 'yes' : 'no'),
    ]);
  }
  // encode(), not save(): on the web save() also triggers its own browser
  // download named "FlutterExcel.xlsx".
  return excel.encode()!;
}

/// `fasting-persons-2027-02-08-19_05.xlsx`
String exportFileName(DateTime now) =>
    'fasting-persons-${formatDayKey(now)}-'
    '${now.hour.toString().padLeft(2, '0')}_'
    '${now.minute.toString().padLeft(2, '0')}.xlsx';

class ExportService {
  Future<void> sharePeople(List<FastingPerson> people) async {
    final now = DateTime.now();
    final bytes = Uint8List.fromList(buildPeopleWorkbook(people, now));
    final name = exportFileName(now);
    final XFile file;
    if (kIsWeb) {
      // No file system on the web: share the bytes; browsers without the
      // share sheet download them under [name].
      file = XFile.fromData(bytes, name: name, mimeType: _xlsxMime);
    } else {
      final dir = await getTemporaryDirectory();
      final saved = File('${dir.path}/$name');
      await saved.writeAsBytes(bytes, flush: true);
      file = XFile(saved.path, name: name, mimeType: _xlsxMime);
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [name],
        subject: 'Fasting persons list',
        downloadFallbackEnabled: true,
      ),
    );
  }
}

final exportServiceProvider = Provider<ExportService>((_) => ExportService());
