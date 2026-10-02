import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iftar_mobile/core/providers.dart';
import 'package:iftar_mobile/features/auth/data/auth_repository.dart';
import 'package:iftar_mobile/features/auth/domain/user.dart';
import 'package:iftar_mobile/features/auth/presentation/auth_controller.dart';
import 'package:iftar_mobile/features/people/presentation/people_filter.dart';

import '../support/fakes.dart';

class _SignedInRepository implements AuthRepository {
  int logouts = 0;

  @override
  Future<User?> restoreSession() async => testUser;

  @override
  Future<User> fetchProfile() async => testUser;

  @override
  Future<User> login(String username, String password) async => testUser;

  @override
  Future<void> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required int regionId,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() async => logouts++;
}

/// The next volunteer on a shared phone starts from a clean list screen.
void main() {
  late _SignedInRepository auth;
  late ProviderContainer container;

  setUp(() async {
    auth = _SignedInRepository();
    container = ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    await container.read(authControllerProvider.future);
    container
      ..listen(peopleFilterProvider, (_, _) {})
      ..listen(peopleSearchQueryProvider, (_, _) {});
    container.read(peopleFilterProvider.notifier).select(PeopleFilter.served);
    container.read(peopleSearchQueryProvider.notifier).update('najwa');
  });

  test('signing out clears the list filter and the search', () async {
    await container.read(authControllerProvider.notifier).logout();
    expect(auth.logouts, 1);
    expect(container.read(peopleFilterProvider), PeopleFilter.all);
    expect(container.read(peopleSearchQueryProvider), '');
  });

  test('a server-side sign-out (expired session) clears them too', () async {
    container.read(sessionExpiredEventsProvider).add(null);
    await Future<void>.delayed(Duration.zero);
    await pumpEventQueue();
    expect(container.read(authControllerProvider).value, isNull);
    expect(container.read(peopleFilterProvider), PeopleFilter.all);
    expect(container.read(peopleSearchQueryProvider), '');
  });

  test('staying signed in keeps them', () async {
    expect(container.read(peopleFilterProvider), PeopleFilter.served);
    expect(container.read(peopleSearchQueryProvider), 'najwa');
  });
}
