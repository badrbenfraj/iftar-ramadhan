import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/storage/device_id.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/domain/user.dart';
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
    final saved = await ref.read(peopleCacheProvider).read(regionId: region.id);
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
    _save(region.id, people);
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
  void _save(int regionId, List<FastingPerson> people) {
    final at = loadedAt;
    if (!ref.mounted || at == null) return;
    unawaited(
      ref
          .read(peopleCacheProvider)
          .write(regionId: regionId, people: people, syncedAt: at),
    );
  }

  void _saveCurrent(List<FastingPerson> people) {
    final region = ref.read(authControllerProvider).value?.region;
    if (region == null) return;
    _save(region.id, people);
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

  /// Local update after a create/edit/confirm, avoiding a full reload. A
  /// person of another region (a global admin browsing) is left out.
  void upsert(FastingPerson person) {
    final current = state.value;
    if (current == null) return;
    final own = ref.read(authControllerProvider).value?.region?.id;
    if (person.region != null && person.region!.id != own) return;
    final next = [
      for (final p in current)
        if (p.id != person.id) p,
      person,
    ]..sort((a, b) => a.id.compareTo(b.id));
    state = AsyncData(next);
    _saveCurrent(next);
  }

  void remove(int id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final p in current)
        if (p.id != id) p,
    ]);
    _saveCurrent(state.value!);
  }
}

final peopleListProvider =
    AsyncNotifierProvider<PeopleListController, List<FastingPerson>>(
      PeopleListController.new,
    );

/// A person: card numbers repeat across regions, so the region is part of
/// the key.
typedef PersonKey = ({int regionId, int id});

/// The person a details route points to: [regionId] from the `region` query
/// parameter (a global admin browsing another region), else the user's own
/// region.
PersonKey personKeyFor(WidgetRef ref, int id, int? regionId) => (
  regionId: regionId ?? regionOf(ref.read(authControllerProvider)).id,
  id: id,
);

/// Route to a person's details; [regionId] only when it isn't the user's own.
String personPath(int id, {int? regionId, bool edit = false}) =>
    '/people/$id${edit ? '/edit' : ''}'
    '${regionId == null ? '' : '?region=$regionId'}';

/// One person, loaded fresh from the server (details screen).
class PersonDetailsController extends AsyncNotifier<FastingPerson> {
  PersonDetailsController(this.key);

  final PersonKey key;

  @override
  Future<FastingPerson> build() =>
      ref.read(peopleRepositoryProvider).get(key.regionId, key.id);

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
    try {
      final updated = await ref
          .read(peopleRepositoryProvider)
          .confirmMeal(
            key.regionId,
            key.id,
            phone: phone,
            comment: comment,
            clientEventId: clientEventId,
            deviceId: await ref.read(deviceIdProvider.future),
          );
      state = AsyncData(updated);
      personChanged(ref, updated);
      return updated;
    } on MealAlreadyTakenFailure {
      final fresh = await ref
          .read(peopleRepositoryProvider)
          .get(key.regionId, key.id);
      state = AsyncData(fresh);
      personChanged(ref, fresh);
      rethrow;
    }
  }

  /// Undoes tonight's meal (spec 2A §4.2). Failures are rethrown.
  Future<FastingPerson> undoMeal(MealEvent meal) async {
    final updated = await ref
        .read(peopleRepositoryProvider)
        .revokeMeal(meal.eventId);
    state = AsyncData(updated);
    personChanged(ref, updated);
    return updated;
  }
}

final personDetailsProvider = AsyncNotifierProvider.autoDispose
    .family<PersonDetailsController, FastingPerson, PersonKey>(
      PersonDetailsController.new,
    );

/// The region a global admin browses on the people list: their own by
/// default, another one, or every region with null. Scanning and the copy
/// saved on the phone always stay on the admin's own region.
class PeopleRegion extends Notifier<int?> {
  @override
  int? build() {
    // Back to the default when another account signs in.
    ref.watch(authControllerProvider.select((a) => a.value?.id));
    return ref.read(authControllerProvider).value?.region?.id;
  }

  void select(int? regionId) => state = regionId;
}

final peopleRegionProvider = NotifierProvider<PeopleRegion, int?>(
  PeopleRegion.new,
);

/// True when a global admin is looking at another region (or every region)
/// instead of their own list.
bool isBrowsingOtherRegion(User? user, int? browsing) =>
    user?.isAdmin == true && browsing != user?.region?.id;

/// People of another region, or of every region with null, for a global
/// admin. Loaded fresh each time and never saved on the phone.
final browsedPeopleProvider = FutureProvider.autoDispose
    .family<List<FastingPerson>, int?>(
      (ref, regionId) => ref.watch(peopleRepositoryProvider).list(regionId),
    );

/// Keeps both lists in step after a person was created, edited or served.
void personChanged(Ref ref, FastingPerson person) {
  ref.read(peopleListProvider.notifier).upsert(person);
  if (isBrowsingOtherRegion(
    ref.read(authControllerProvider).value,
    ref.read(peopleRegionProvider),
  )) {
    ref.invalidate(browsedPeopleProvider);
  }
}
