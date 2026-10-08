import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/storage/device_id.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/people_cache.dart';
import '../data/people_repository.dart';
import '../domain/fasting_person.dart';
import '../domain/meal_event.dart';

/// The region's list of fasting people (Ionic tab "list").
class PeopleListController extends AsyncNotifier<List<FastingPerson>> {
  /// When the list on screen was loaded from the server (for the copy saved
  /// on the phone: when that copy was). The "served tonight" flags in it
  /// describe that day only.
  DateTime? loadedAt;

  /// True while the list on screen is the copy saved on this phone and no
  /// server answer has replaced it yet (spec 2A §5.4).
  bool fromCache = false;

  @override
  Future<List<FastingPerson>> build() async {
    // Reload when the signed-in user's region changes.
    ref.watch(authControllerProvider.select((a) => a.value?.region?.id));
    loadedAt = null;
    fromCache = false;
    final region = requireRegion(ref);
    final saved = await ref
        .read(peopleCacheProvider)
        .read(regionId: region.id);
    if (saved != null) {
      loadedAt = saved.syncedAt;
      fromCache = true;
      // Shown at once; the server's list replaces it when it arrives.
      unawaited(_refreshQuietly());
      return saved.people;
    }
    return _load();
  }

  Future<List<FastingPerson>> _load() async {
    final region = requireRegion(ref);
    final people = await ref.read(peopleRepositoryProvider).list(region.id);
    loadedAt = ref.read(clockProvider)();
    fromCache = false;
    _save(people);
    return people;
  }

  Future<void> _refreshQuietly() async {
    try {
      final people = await _load();
      if (ref.mounted) state = AsyncData(people);
    } on Object {
      // Offline: the saved list stays on screen, marked with its time.
    }
  }

  /// Keeps the copy on the phone in step with the list on screen.
  void _save(List<FastingPerson> people) {
    final region = ref.read(authControllerProvider).value?.region;
    final at = loadedAt;
    if (region == null || at == null) return;
    unawaited(
      ref
          .read(peopleCacheProvider)
          .write(regionId: region.id, people: people, syncedAt: at),
    );
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
    _save(next);
  }

  void remove(int id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final p in current)
        if (p.id != id) p,
    ]);
    _save(state.value!);
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
