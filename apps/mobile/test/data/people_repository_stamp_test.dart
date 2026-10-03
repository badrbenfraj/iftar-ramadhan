import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/api_client.dart';
import 'package:iftar_mobile/features/people/data/people_repository.dart';

class _StubApi extends ApiClient {
  _StubApi() : super(Dio());

  static const person = {
    'id': 7,
    'firstName': 'Najwa',
    'lastName': 'Chalbi',
    'singleMeal': 1,
    'familyMeal': 0,
    'mealTakenToday': true,
  };

  @override
  Future<ApiEnvelope> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? extra,
  }) async => ApiEnvelope(path.endsWith('/7') ? person : [person], const {});

  @override
  Future<ApiEnvelope> patch(String path, {Object? body}) async =>
      const ApiEnvelope(person, {});
}

/// The served flag is only good for the day it arrived, so every person the
/// repository returns carries the time it was received.
void main() {
  var now = DateTime(2025, 3, 5, 18, 30);
  final repo = ApiPeopleRepository(_StubApi(), clock: () => now);
  final nextEvening = DateTime(2025, 3, 6, 18, 30);

  test('a listed person expires with the day', () async {
    final p = (await repo.list(1)).single;
    expect(p.isMealTakenToday(DateTime(2025, 3, 5, 22)), isTrue);
    expect(p.isMealTakenToday(nextEvening), isFalse);
  });

  test('a fetched or confirmed person expires with the day', () async {
    final got = await repo.get(1, 7);
    final confirmed = await repo.confirmMeal(1, 7);
    for (final p in [got, confirmed]) {
      expect(p.isMealTakenToday(DateTime(2025, 3, 5, 22)), isTrue);
      expect(p.isMealTakenToday(nextEvening), isFalse);
    }
  });

  test('the stamp is the injected clock, read per call', () async {
    now = DateTime(2025, 3, 6, 9);
    final p = (await repo.list(1)).single;
    expect(p.isMealTakenToday(DateTime(2025, 3, 6, 22)), isTrue);
    expect(p.isMealTakenToday(DateTime(2025, 3, 7, 12)), isFalse);
  });
}
