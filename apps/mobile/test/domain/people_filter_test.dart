import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/features/people/presentation/people_filter.dart';

import '../support/fakes.dart';

void main() {
  final people = [
    person(1, first: 'Najwa', last: 'Chalbi'),
    person(2, first: 'Aziza', last: 'Ouerghi', takenToday: true),
    person(3, first: 'Najib', last: 'Saidi'),
  ];

  test('counts waiting and served tonight', () {
    final c = countPeople(people, testNow);
    expect((c.total, c.waiting, c.served), (3, 2, 1));
  });

  test('filters combine with the search query', () {
    List<int> ids(PeopleFilter f, String q) => [
      for (final p in applyPeopleFilter(people, filter: f, query: q, now: testNow)) p.id,
    ];
    expect(ids(PeopleFilter.all, ''), [1, 2, 3]);
    expect(ids(PeopleFilter.waiting, ''), [1, 3]);
    expect(ids(PeopleFilter.served, ''), [2]);
    expect(ids(PeopleFilter.waiting, 'naj'), [1, 3]);
    expect(ids(PeopleFilter.served, 'naj'), isEmpty);
  });
}
