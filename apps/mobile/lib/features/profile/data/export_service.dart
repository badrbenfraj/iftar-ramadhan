import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/formatters.dart';
import '../../people/domain/fasting_person.dart';

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
  return excel.save()!;
}

class ExportService {
  Future<void> sharePeople(List<FastingPerson> people) async {
    final now = DateTime.now();
    final bytes = buildPeopleWorkbook(people, now);
    final dir = await getTemporaryDirectory();
    final stamp =
        '${formatDayKey(now)}-${now.hour.toString().padLeft(2, '0')}_'
        '${now.minute.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/fasting-persons-$stamp.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Fasting persons list',
      ),
    );
  }
}

final exportServiceProvider = Provider<ExportService>((_) => ExportService());
