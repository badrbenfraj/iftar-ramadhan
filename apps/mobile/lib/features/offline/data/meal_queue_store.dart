import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/storage/encrypted_json_file.dart';
import '../domain/offline_meal.dart';

class MealQueueSnapshot {
  const MealQueueSnapshot({this.pending = const [], this.review = const []});

  final List<PendingMeal> pending;
  final List<ReviewItem> review;
}

/// Meals served offline and items to review, kept across restarts
/// (spec 2B §5.2). Not wiped on logout: unsynced meals are real meals.
abstract interface class MealQueueStore {
  Future<MealQueueSnapshot> load();
  /// True when the snapshot reached storage.
  Future<bool> save(MealQueueSnapshot snapshot);
}

class EncryptedMealQueueStore implements MealQueueStore {
  EncryptedMealQueueStore(this._file);

  final EncryptedJsonFile _file;

  @override
  Future<MealQueueSnapshot> load() async {
    final main = _snapshot(await _file.read());
    try {
      final aside = await _file.readSetAside();
      if (aside.isEmpty) return main;
      // Files set aside after a failed read are merged back, so no meal
      // served offline is lost. The main file wins on a repeated ID.
      final pending = [...main.pending];
      final review = [...main.review];
      final ids = {
        for (final m in pending) m.clientEventId,
        for (final r in review) r.clientEventId,
      };
      for (final (_, json) in aside) {
        final snap = _snapshot(json);
        for (final m in snap.pending) {
          if (ids.add(m.clientEventId)) pending.add(m);
        }
        for (final r in snap.review) {
          if (ids.add(r.clientEventId)) review.add(r);
        }
      }
      final merged = MealQueueSnapshot(pending: pending, review: review);
      // Delete the set-aside files only once the merge is safely saved. If
      // the save failed they stay, and the next start merges them again;
      // dedupe by clientEventId makes that safe.
      if (await save(merged)) {
        for (final (file, _) in aside) {
          try {
            await file.delete();
          } on Object {
            // Merged already; a leftover file only repeats entries.
          }
        }
      }
      return merged;
    } on Object {
      return main;
    }
  }

  static MealQueueSnapshot _snapshot(Object? json) {
    if (json is! Map<String, dynamic>) return const MealQueueSnapshot();
    return MealQueueSnapshot(
      pending: [
        for (final m in (json['pending'] as List?) ?? const [])
          ?_parse(m, PendingMeal.fromJson),
      ],
      review: [
        for (final r in (json['review'] as List?) ?? const [])
          ?_parse(r, ReviewItem.fromJson),
      ],
    );
  }

  /// One bad entry must not drop the others.
  static T? _parse<T>(Object? json, T Function(Map<String, dynamic>) from) {
    if (json is! Map<String, dynamic>) return null;
    try {
      return from(json);
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> save(MealQueueSnapshot snapshot) => _file.write({
    'v': 1,
    'pending': [for (final m in snapshot.pending) m.toJson()],
    'review': [for (final r in snapshot.review) r.toJson()],
  });
}

/// In memory, for tests and previews.
class MemoryMealQueueStore implements MealQueueStore {
  MealQueueSnapshot saved = const MealQueueSnapshot();

  @override
  Future<MealQueueSnapshot> load() async => saved;

  @override
  Future<bool> save(MealQueueSnapshot snapshot) async {
    saved = snapshot;
    return true;
  }
}

final mealQueueStoreProvider = Provider<MealQueueStore>(
  (ref) => EncryptedMealQueueStore(
    EncryptedJsonFile(
      directory: getApplicationDocumentsDirectory,
      keys: ref.watch(settingsStorageProvider),
      fileName: 'meal_queue.bin',
      keyName: 'meal_queue_key',
    ),
  ),
);
