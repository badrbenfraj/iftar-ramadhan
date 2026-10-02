import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/providers.dart';
import 'package:iftar_mobile/features/auth/domain/user.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/people/data/people_repository.dart';
import 'package:iftar_mobile/features/people/domain/fasting_person.dart';
import 'package:iftar_mobile/features/people/domain/person_draft.dart';

const testRegion = Region(id: 1, name: 'Dar Sokra');

const testUser = User(
  id: 2,
  name: 'Vol One',
  username: 'vol1',
  email: 'vol1@example.com',
  roles: ['USER'],
  isAccountDisabled: false,
  region: testRegion,
);

/// 18:30 local on a Ramadan evening.
final testNow = DateTime(2025, 3, 5, 18, 30);

FastingPerson person(
  int id, {
  bool takenToday = false,
  String first = 'Najwa',
  String last = 'Chalbi',
}) => FastingPerson(
  id: id,
  firstName: first,
  lastName: last,
  singleMeal: 2,
  familyMeal: 1,
  lastTakenMeal: takenToday
      ? testNow.subtract(const Duration(minutes: 20))
      : testNow.subtract(const Duration(days: 1)),
  mealTakenTodayFromServer: takenToday,
  region: testRegion,
);

class FakeAuthController extends AuthController {
  FakeAuthController([this.user = testUser]);

  final User? user;

  @override
  Future<User?> build() async => user;
}

/// In-memory backend that enforces one meal per person per day.
class FakePeopleRepository implements PeopleRepository {
  FakePeopleRepository(Iterable<FastingPerson> seed)
    : people = {for (final p in seed) p.id: p};

  final Map<int, FastingPerson> people;
  AppFailure? nextGetFailure;
  AppFailure? nextConfirmFailure;

  /// Simulates "server committed, but the response was lost".
  bool applyThenFailConfirm = false;
  int confirmCalls = 0;
  ({String? phone, String? comment})? lastConfirmBody;

  /// When set, the next `get` waits for it (then clears it).
  Completer<void>? getGate;

  @override
  Future<List<FastingPerson>> list(int regionId) async =>
      people.values.toList();

  @override
  Future<FastingPerson> get(int regionId, int id) async {
    final gate = getGate;
    if (gate != null) {
      getGate = null;
      await gate.future;
    }
    final failure = nextGetFailure;
    if (failure != null) {
      nextGetFailure = null;
      throw failure;
    }
    final p = people[id];
    if (p == null) throw const NotFoundFailure();
    return p;
  }

  @override
  Future<FastingPerson> confirmMeal(
    int regionId,
    int id, {
    String? phone,
    String? comment,
  }) async {
    confirmCalls++;
    lastConfirmBody = (phone: phone, comment: comment);
    final failure = nextConfirmFailure;
    if (failure != null && !applyThenFailConfirm) {
      nextConfirmFailure = null;
      throw failure;
    }
    final p = people[id];
    if (p == null) throw const NotFoundFailure();
    if (p.isMealTakenToday(testNow)) {
      throw MealAlreadyTakenFailure(takenAt: p.lastTakenMeal);
    }
    final updated = p.copyWith(
      phone: phone,
      comment: comment,
      lastTakenMeal: testNow,
      mealTakenTodayFromServer: true,
      takenMeals: [testNow, ...p.takenMeals],
    );
    people[id] = updated;
    if (failure != null) {
      nextConfirmFailure = null;
      applyThenFailConfirm = false;
      throw failure;
    }
    return updated;
  }

  int createCalls = 0;

  @override
  Future<FastingPerson> create(int regionId, PersonDraft draft) async {
    createCalls++;
    if (people.containsKey(draft.id)) throw const ConflictFailure('exists');
    final cin = draft.cin?.trim();
    final p = FastingPerson(
      id: draft.id,
      firstName: draft.firstName.trim(),
      lastName: draft.lastName.trim(),
      cin: (cin == null || cin.isEmpty) ? null : cin,
      singleMeal: draft.singleMeal,
      familyMeal: draft.familyMeal,
      lastTakenMeal: draft.cameToday ? testNow : null,
      mealTakenTodayFromServer: draft.cameToday,
      takenMeals: draft.cameToday ? [testNow] : const [],
      region: testRegion,
    );
    people[p.id] = p;
    return p;
  }

  int updateCalls = 0;

  @override
  Future<FastingPerson> update(Region region, PersonDraft draft) async {
    updateCalls++;
    final old = people[draft.id];
    if (old == null) throw const NotFoundFailure();
    final cin = draft.cin?.trim();
    final updated = FastingPerson(
      id: old.id,
      firstName: draft.firstName.trim(),
      lastName: draft.lastName.trim(),
      cin: (cin == null || cin.isEmpty) ? null : cin,
      phone: draft.phone,
      comment: draft.comment,
      singleMeal: draft.singleMeal,
      familyMeal: draft.familyMeal,
      lastTakenMeal: old.lastTakenMeal,
      takenMeals: old.takenMeals,
      mealTakenTodayFromServer: old.mealTakenTodayFromServer,
      region: old.region,
    );
    people[updated.id] = updated;
    return updated;
  }

  @override
  Future<void> delete(int regionId, int id) async => people.remove(id);
}

List<Override> testOverrides(
  FakePeopleRepository repo, {
  User? user = testUser,
  DateTime Function()? clock,
}) => [
  authControllerProvider.overrideWith(() => FakeAuthController(user)),
  peopleRepositoryProvider.overrideWithValue(repo),
  clockProvider.overrideWithValue(clock ?? () => testNow),
];
