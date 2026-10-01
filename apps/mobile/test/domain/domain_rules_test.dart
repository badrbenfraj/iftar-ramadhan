import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/people/domain/person_draft.dart';
import 'package:iftar_mobile/features/scan/domain/qr_payload.dart';
import 'package:iftar_mobile/features/statistics/domain/statistics.dart';

void main() {
  group('QrPayload.parse', () {
    test('accepts a numeric person ID', () {
      final result = QrPayload.parse(' 246 ');
      expect(result, isA<PersonQr>());
      expect((result as PersonQr).personId, 246);
    });

    test('tolerates a leading # and leading zeros', () {
      expect((QrPayload.parse('#0042') as PersonQr).personId, 42);
    });

    test(
      'rejects empty, non-numeric, zero, negative and overflowing codes',
      () {
        for (final raw in [
          null,
          '',
          '   ',
          'abc',
          'https://example.com/12',
          '12a',
          '0',
          '-5',
          '4.5',
          '99999999999',
        ]) {
          expect(QrPayload.parse(raw), isA<InvalidQr>(), reason: '$raw');
        }
      },
    );
  });

  group('PersonRules', () {
    test('at least one meal type must be > 0; empty becomes 0', () {
      expect(PersonRules.normalizeMeals('2', ''), (single: 2, family: 0));
      expect(PersonRules.normalizeMeals('', '1'), (single: 0, family: 1));
      expect(PersonRules.normalizeMeals('0', '3'), (single: 0, family: 3));
      expect(PersonRules.normalizeMeals('0', '0'), isNull);
      expect(PersonRules.normalizeMeals('', ''), isNull);
      expect(PersonRules.normalizeMeals('-1', '2'), isNull);
    });

    test('CIN is optional but exactly 8 characters', () {
      expect(PersonRules.validateCin(''), isNull);
      expect(PersonRules.validateCin('12345678'), isNull);
      expect(PersonRules.validateCin('1234567'), isNotNull);
      expect(PersonRules.validateCin('123456789'), isNotNull);
    });

    test('identifier is a required positive integer', () {
      expect(PersonRules.validateId(''), 'Identifier is required');
      expect(PersonRules.validateId('0'), isNotNull);
      expect(PersonRules.validateId('12'), isNull);
    });
  });

  group('FastingPerson', () {
    final json = {
      'id': 7,
      'firstName': 'نجوى ',
      'lastName': 'شلبي',
      'cin': '',
      'singleMeal': 2,
      'familyMeal': 1,
      'lastTakenMeal': '2025-03-03T17:10:00.000Z',
      'takenMeals': [
        '2025-03-01T17:00:00.000+01:00',
        'Sat Mar 01 2025 18:00:00 GMT+0100', // legacy, unparseable: skipped
        '2025-03-03T17:10:00.000Z',
      ],
      'region': {'id': 1, 'name': 'Dar Sokra'},
    };

    test('parses the API shape, trimming names and dropping empty fields', () {
      final p = FastingPerson.fromJson(json);
      expect(p.fullName, 'نجوى شلبي');
      expect(p.cin, isNull);
      expect(p.takenMeals, hasLength(2));
      expect(p.takenMeals.first.isAfter(p.takenMeals.last), isTrue);
      expect(p.region?.name, 'Dar Sokra');
      expect(p.totalPortions, 6); // family meal = 4 portions
    });

    test('the server flag wins over the device clock', () {
      final p = FastingPerson.fromJson({...json, 'mealTakenToday': false});
      expect(p.isMealTakenToday(DateTime(2025, 3, 3, 20)), isFalse);
    });

    test('a person registered without a meal has no history yet', () {
      final p = FastingPerson.fromJson({
        ...json,
        'lastTakenMeal': null,
        'takenMeals': <String>[],
      });
      expect(p.lastTakenMeal, isNull);
      expect(p.takenMeals, isEmpty);
      // Eligible today, with or without the server flag (older backends).
      expect(p.isMealTakenToday(DateTime(2025, 3, 3, 20)), isFalse);
      expect(
        FastingPerson.fromJson({
          ...json,
          'lastTakenMeal': null,
          'takenMeals': <String>[],
          'mealTakenToday': false,
        }).isMealTakenToday(DateTime(2025, 3, 3, 20)),
        isFalse,
      );
    });

    test('falls back to comparing lastTakenMeal with the local day', () {
      final p = FastingPerson.fromJson(json);
      final taken = p.lastTakenMeal!;
      expect(p.isMealTakenToday(taken.add(const Duration(minutes: 5))), isTrue);
      expect(p.isMealTakenToday(taken.add(const Duration(days: 1))), isFalse);
    });

    test('search matches ID, names in any order, CIN and phone', () {
      final p = FastingPerson.fromJson({
        ...json,
        'cin': '09876543',
        'phone': '22 123 456',
      });
      expect(p.matches('7'), isTrue);
      expect(p.matches('شلبي نجوى'), isTrue);
      expect(p.matches('0987'), isTrue);
      expect(p.matches('22123'), isTrue);
      expect(p.matches('zzz'), isFalse);
    });
  });

  group('StatsPeriod', () {
    final wednesday = DateTime(2025, 3, 5, 15);

    test('daily is today', () {
      final r = StatsPeriod.daily.rangeFor(wednesday);
      expect(r.from, DateTime(2025, 3, 5));
      expect(r.to, DateTime(2025, 3, 5));
    });

    test('weekly runs Sunday to Saturday (as in the Ionic app)', () {
      final r = StatsPeriod.weekly.rangeFor(wednesday);
      expect(r.from, DateTime(2025, 3, 2)); // Sunday
      expect(r.to, DateTime(2025, 3, 8)); // Saturday
      final sunday = StatsPeriod.weekly.rangeFor(DateTime(2025, 3, 2));
      expect(sunday.from, DateTime(2025, 3, 2));
    });

    test('monthly covers the whole month', () {
      final r = StatsPeriod.monthly.rangeFor(DateTime(2024, 2, 10));
      expect(r.from, DateTime(2024, 2, 1));
      expect(r.to, DateTime(2024, 2, 29)); // leap year
    });

    test('summary adds up daily figures', () {
      final days = [
        DailyStatistics.fromJson({
          'date': 'Mon Mar 03 2025',
          'statistics': {
            'persons': 2,
            'totalPersons': 9,
            'singleMeal': 3,
            'familyMeal': 8,
            'totalMeals': 11,
          },
        }),
        DailyStatistics.fromJson({
          'date': 'Tue Mar 04 2025',
          'statistics': {
            'persons': 1,
            'totalPersons': 9,
            'singleMeal': 1,
            'familyMeal': 0,
            'totalMeals': 1,
          },
        }),
      ];
      final s = StatisticsSummary(days);
      expect(s.persons, 3);
      expect(s.totalMeals, 12);
    });
  });
}
