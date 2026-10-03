import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/fasting_person.dart';

enum PeopleFilter { all, waiting, served }

typedef PeopleCounts = ({int total, int waiting, int served});

PeopleCounts countPeople(Iterable<FastingPerson> people, DateTime now) {
  var served = 0;
  var total = 0;
  for (final p in people) {
    total++;
    if (p.isMealTakenToday(now)) served++;
  }
  return (total: total, waiting: total - served, served: served);
}

List<FastingPerson> applyPeopleFilter(
  Iterable<FastingPerson> people, {
  required PeopleFilter filter,
  required String query,
  required DateTime now,
}) {
  final matches = FastingPerson.searchMatcher(query);
  return [
    for (final p in people)
      if (matches(p) &&
          switch (filter) {
            PeopleFilter.all => true,
            PeopleFilter.waiting => !p.isMealTakenToday(now),
            PeopleFilter.served => p.isMealTakenToday(now),
          })
        p,
  ];
}

class PeopleFilterController extends Notifier<PeopleFilter> {
  @override
  PeopleFilter build() => PeopleFilter.all;

  void select(PeopleFilter filter) => state = filter;
}

final peopleFilterProvider =
    NotifierProvider<PeopleFilterController, PeopleFilter>(
      PeopleFilterController.new,
    );

class PeopleSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

final peopleSearchQueryProvider = NotifierProvider<PeopleSearchQuery, String>(
  PeopleSearchQuery.new,
);
