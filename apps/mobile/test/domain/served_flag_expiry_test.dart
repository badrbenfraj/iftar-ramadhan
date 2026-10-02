import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/people/presentation/people_filter.dart';

/// The server's "served tonight" flag describes the day it was received; the
/// phone has no push, so it must stop applying once the calendar day moves on.
void main() {
  final received = DateTime(2025, 3, 5, 18, 40);
  final json = {
    'id': 7,
    'firstName': 'Najwa',
    'lastName': 'Chalbi',
    'singleMeal': 2,
    'familyMeal': 1,
    'lastTakenMeal': DateTime(2025, 3, 5, 18, 20).toIso8601String(),
    'mealTakenToday': true,
  };

  FastingPerson served() =>
      FastingPerson.fromJson(json, receivedAt: received);

  test('the flag holds for the rest of the day it was received', () {
    expect(served().isMealTakenToday(DateTime(2025, 3, 5, 23, 59)), isTrue);
  });

  test('the next evening the same person is waiting again', () {
    expect(served().isMealTakenToday(DateTime(2025, 3, 6, 18, 30)), isFalse);
  });

  test('a flag with no receive time is trusted (hand-built people)', () {
    final p = FastingPerson.fromJson(json);
    expect(p.isMealTakenToday(DateTime(2025, 3, 9, 18, 30)), isTrue);
  });

  test('a waiting flag stays waiting', () {
    final p = FastingPerson.fromJson(
      {...json, 'mealTakenToday': false},
      receivedAt: received,
    );
    expect(p.isMealTakenToday(DateTime(2025, 3, 5, 21)), isFalse);
  });

  test('copyWith keeps the receive time', () {
    final p = served().copyWith(comment: 'x');
    expect(p.isMealTakenToday(DateTime(2025, 3, 6, 18, 30)), isFalse);
  });

  test('counts and filters follow the expiry', () {
    final people = [served()];
    final nextEvening = DateTime(2025, 3, 6, 18, 30);
    expect(countPeople(people, DateTime(2025, 3, 5, 19)).served, 1);
    expect(countPeople(people, nextEvening), (total: 1, waiting: 1, served: 0));
    expect(
      applyPeopleFilter(
        people,
        filter: PeopleFilter.waiting,
        query: '',
        now: nextEvening,
      ),
      hasLength(1),
    );
  });
}
