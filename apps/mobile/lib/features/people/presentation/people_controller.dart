import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/people_repository.dart';
import '../domain/fasting_person.dart';

/// The region's list of fasting people (Ionic tab "list").
class PeopleListController extends AsyncNotifier<List<FastingPerson>> {
  @override
  Future<List<FastingPerson>> build() {
    // Reload when the signed-in user's region changes.
    ref.watch(authControllerProvider.select((a) => a.value?.region?.id));
    return _load();
  }

  Future<List<FastingPerson>> _load() async {
    final region = requireRegion(ref);
    return ref.read(peopleRepositoryProvider).list(region.id);
  }

  /// Pull-to-refresh. On failure the previous list stays visible and the
  /// failure is rethrown so the page can tell the volunteer.
  Future<void> refresh() async {
    try {
      state = AsyncData(await _load());
    } catch (e, st) {
      final failure = toAppFailure(e);
      if (!state.hasValue) state = AsyncError(failure, st);
      throw failure;
    }
  }

  /// Local update after a create/edit/confirm, avoiding a full reload.
  void upsert(FastingPerson person) {
    final current = state.value;
    if (current == null) return;
    final next = [
      for (final p in current)
        if (p.id != person.id) p,
      person,
    ]..sort((a, b) => a.id.compareTo(b.id));
    state = AsyncData(next);
  }

  void remove(int id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final p in current)
        if (p.id != id) p,
    ]);
  }
}

final peopleListProvider =
    AsyncNotifierProvider<PeopleListController, List<FastingPerson>>(
      PeopleListController.new,
    );

class PeopleSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

final peopleSearchQueryProvider = NotifierProvider<PeopleSearchQuery, String>(
  PeopleSearchQuery.new,
);

/// One person, loaded fresh from the server (details screen).
class PersonDetailsController extends AsyncNotifier<FastingPerson> {
  PersonDetailsController(this.personId);

  final int personId;

  @override
  Future<FastingPerson> build() {
    final region = requireRegion(ref);
    return ref.read(peopleRepositoryProvider).get(region.id, personId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Confirms today's meal. On "already taken" the person is reloaded so the
  /// screen reflects the server state, and the failure is rethrown.
  Future<FastingPerson> confirmMeal({String? phone, String? comment}) async {
    final region = requireRegion(ref);
    try {
      final updated = await ref
          .read(peopleRepositoryProvider)
          .confirmMeal(region.id, personId, phone: phone, comment: comment);
      state = AsyncData(updated);
      ref.read(peopleListProvider.notifier).upsert(updated);
      return updated;
    } on MealAlreadyTakenFailure {
      final fresh = await ref
          .read(peopleRepositoryProvider)
          .get(region.id, personId);
      state = AsyncData(fresh);
      ref.read(peopleListProvider.notifier).upsert(fresh);
      rethrow;
    }
  }
}

final personDetailsProvider = AsyncNotifierProvider.autoDispose
    .family<PersonDetailsController, FastingPerson, int>(
      PersonDetailsController.new,
    );
