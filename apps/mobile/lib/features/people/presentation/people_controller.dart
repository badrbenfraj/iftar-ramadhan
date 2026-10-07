import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/storage/device_id.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/people_repository.dart';
import '../domain/fasting_person.dart';
import '../domain/meal_event.dart';

/// The region's list of fasting people (Ionic tab "list").
class PeopleListController extends AsyncNotifier<List<FastingPerson>> {
  /// When the list was last loaded from the server. The "served tonight"
  /// flags in it describe that day only.
  DateTime? loadedAt;

  @override
  Future<List<FastingPerson>> build() {
    // Reload when the signed-in user's region changes.
    ref.watch(authControllerProvider.select((a) => a.value?.region?.id));
    loadedAt = null;
    return _load();
  }

  Future<List<FastingPerson>> _load() async {
    final region = requireRegion(ref);
    final people = await ref.read(peopleRepositoryProvider).list(region.id);
    loadedAt = ref.read(clockProvider)();
    return people;
  }

  /// Called when the app returns to the foreground: the phone gets no push
  /// at midnight, so a list loaded on an earlier day is reloaded. A failed
  /// reload keeps the list on screen (its stale flags already expire) and is
  /// tried again at the next resume.
  Future<void> reloadIfDayChanged() async {
    final at = loadedAt;
    if (at == null || isSameDay(at, ref.read(clockProvider)())) return;
    try {
      await refresh();
    } on Object {
      // Kept: see above.
    }
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

  /// Confirms today's meal. [clientEventId] must be reused when the same
  /// confirm is retried (spec 2A §5.1). On "already taken" the person is
  /// reloaded so the screen reflects the server state, and the failure is
  /// rethrown.
  Future<FastingPerson> confirmMeal({
    String? phone,
    String? comment,
    String? clientEventId,
  }) async {
    final region = requireRegion(ref);
    try {
      final updated = await ref
          .read(peopleRepositoryProvider)
          .confirmMeal(
            region.id,
            personId,
            phone: phone,
            comment: comment,
            clientEventId: clientEventId,
            deviceId: await ref.read(deviceIdProvider.future),
          );
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

  /// Undoes tonight's meal (spec 2A §4.2). Failures are rethrown.
  Future<FastingPerson> undoMeal(MealEvent meal) async {
    final updated = await ref
        .read(peopleRepositoryProvider)
        .revokeMeal(meal.eventId);
    state = AsyncData(updated);
    ref.read(peopleListProvider.notifier).upsert(updated);
    return updated;
  }
}

final personDetailsProvider = AsyncNotifierProvider.autoDispose
    .family<PersonDetailsController, FastingPerson, int>(
      PersonDetailsController.new,
    );
