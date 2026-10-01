// Full-stack contract test: the Flutter data layer against a running backend.
//
// Skipped unless a backend URL is given, e.g.
//   flutter test test/integration \
//     --dart-define=IT_API_BASE_URL=http://localhost:3000/api/v1 \
//     --dart-define=IT_USERNAME=vol1 --dart-define=IT_PASSWORD=secret12
//
// The account must belong to a region. The test creates people with random
// IDs and never deletes data other than what it created.
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/network/api_client.dart';
import 'package:iftar_mobile/core/network/app_failure.dart';
import 'package:iftar_mobile/core/network/auth_interceptor.dart';
import 'package:iftar_mobile/core/storage/session_storage.dart';
import 'package:iftar_mobile/features/auth/data/auth_repository.dart';
import 'package:iftar_mobile/features/people/data/people_repository.dart';
import 'package:iftar_mobile/features/people/domain/person_draft.dart';
import 'package:iftar_mobile/features/statistics/data/statistics_repository.dart';

const _baseUrl = String.fromEnvironment('IT_API_BASE_URL');
const _username = String.fromEnvironment('IT_USERNAME', defaultValue: 'vol1');
const _password = String.fromEnvironment(
  'IT_PASSWORD',
  defaultValue: 'secret12',
);

class MemorySessionStorage implements SessionStorage {
  String? access;
  String? refresh;
  Map<String, dynamic>? user;

  @override
  Future<String?> readAccessToken() async => access;
  @override
  Future<String?> readRefreshToken() async => refresh;
  @override
  Future<Map<String, dynamic>?> readUser() async => user;
  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken ?? refresh;
  }

  @override
  Future<void> saveUser(Map<String, dynamic> value) async => user = value;
  @override
  Future<void> clear() async => access = refresh = user = null;
}

void main() {
  final skip = _baseUrl.isEmpty ? 'IT_API_BASE_URL not set' : null;

  late MemorySessionStorage storage;
  late ApiAuthRepository auth;
  late ApiPeopleRepository people;
  late ApiStatisticsRepository stats;
  var expired = 0;

  setUpAll(() {
    storage = MemorySessionStorage();
    final options = ApiClient.baseOptions(_baseUrl);
    final dio = Dio(options)
      ..interceptors.add(
        AuthInterceptor(
          storage: storage,
          refreshClient: Dio(options),
          onSessionExpired: () => expired++,
        ),
      );
    final api = ApiClient(dio);
    auth = ApiAuthRepository(api, storage);
    people = ApiPeopleRepository(api);
    stats = ApiStatisticsRepository(api);
  });

  test('wrong password is reported as bad credentials', () async {
    await expectLater(
      auth.login(_username, 'definitely-wrong'),
      throwsA(
        isA<UnauthorizedFailure>().having(
          (f) => f.message,
          'message',
          'Wrong username or password.',
        ),
      ),
    );
  }, skip: skip);

  test('scan workflow end to end', () async {
    final user = await auth.login(_username, _password);
    expect(user.region, isNotNull);
    expect(storage.user, isNot(contains('password')));
    final regionId = user.region!.id;

    final id = 500000 + Random().nextInt(400000);
    final created = await people.create(
      regionId,
      PersonDraft(
        id: id,
        firstName: 'عبد الرزاق',
        lastName: 'الشهيبي',
        singleMeal: 2,
        familyMeal: 1,
        cameToday: false,
      ),
    );
    expect(created.firstName, 'عبد الرزاق');
    expect(created.isMealTakenToday(), isFalse);

    // Duplicate ID is refused instead of overwriting someone.
    await expectLater(
      people.create(
        regionId,
        PersonDraft(
          id: id,
          firstName: 'X',
          lastName: 'Y',
          singleMeal: 1,
          familyMeal: 0,
        ),
      ),
      throwsA(
        isA<ConflictFailure>().having((f) => f.code, 'code', 'PERSON_ID_TAKEN'),
      ),
    );

    // Expired/invalid access token: refreshed transparently, request retried.
    storage.access = 'not-a-valid-jwt';
    final scanned = await people.get(regionId, id);
    expect(scanned.id, id);
    expect(storage.access, isNot('not-a-valid-jwt'));
    expect(expired, 0);

    final confirmed = await people.confirmMeal(
      regionId,
      id,
      comment: 'first pickup',
    );
    expect(confirmed.isMealTakenToday(), isTrue);
    expect(confirmed.comment, 'first pickup');

    await expectLater(
      people.confirmMeal(regionId, id),
      throwsA(
        isA<MealAlreadyTakenFailure>().having(
          (f) => f.takenAt,
          'takenAt',
          isNotNull,
        ),
      ),
    );

    await expectLater(
      people.get(regionId, 999999999),
      throwsA(isA<NotFoundFailure>()),
    );

    final list = await people.list(regionId);
    expect(list.map((p) => p.id), contains(id));

    final today = DateTime.now();
    final days = await stats.fetch(regionId, today, today);
    expect(days, hasLength(1));
    expect(days.single.persons, greaterThanOrEqualTo(1));

    await people.delete(regionId, id);
    await expectLater(
      people.get(regionId, id),
      throwsA(isA<NotFoundFailure>()),
    );
  }, skip: skip);
}
