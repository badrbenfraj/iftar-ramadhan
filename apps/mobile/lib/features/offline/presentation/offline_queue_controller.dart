import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/connectivity.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../people/data/people_repository.dart';
import '../../people/presentation/people_controller.dart';
import '../data/meal_queue_store.dart';
import '../domain/offline_meal.dart';

/// What an undo of an offline meal achieved.
enum RemoveOutcome {
  /// Dropped from the phone; the server never had it.
  removed,

  /// The server recorded it: undo it on the server.
  synced,

  /// Sent but unanswered, and still no answer: the Undo needs a connection.
  unknown,
}

/// Shown once as "{n} offline meals synced". A new object every time.
class SyncedNotice {
  SyncedNotice(this.count);
  final int count;
}

class OfflineQueueState {
  const OfflineQueueState({
    this.pending = const [],
    this.review = const [],
    this.syncing = false,
    this.lastSynced,
  });

  final List<PendingMeal> pending;
  final List<ReviewItem> review;
  final bool syncing;
  final SyncedNotice? lastSynced;

  List<PendingMeal> pendingFor(int? userId) => [
    for (final m in pending)
      if (m.userId == userId) m,
  ];

  List<ReviewItem> reviewFor(int? userId) => [
    for (final r in review)
      if (r.userId == userId) r,
  ];

  OfflineQueueState copyWith({
    List<PendingMeal>? pending,
    List<ReviewItem>? review,
    bool? syncing,
    SyncedNotice? lastSynced,
  }) => OfflineQueueState(
    pending: pending ?? this.pending,
    review: review ?? this.review,
    syncing: syncing ?? this.syncing,
    lastSynced: lastSynced ?? this.lastSynced,
  );
}

/// Meals served with no network and their sync (spec 2B §5.2). Flushed when
/// the connection comes back, when the app resumes, every [flushEvery]
/// while meals are pending, and on pull-to-refresh. Each volunteer syncs
/// only their own meals.
class OfflineQueueController extends Notifier<OfflineQueueState> {
  OfflineQueueController({this.flushEvery = const Duration(seconds: 30)});

  final Duration flushEvery;

  /// Matches the server's batch limit.
  static const batchSize = 200;

  Timer? _timer;
  Future<void>? _restoring;

  /// Completes when the flush in progress, if any, is over.
  Future<void>? _flushing;

  /// Meals sent in a flush that gave no answer for them: the server may
  /// have them.
  final Set<String> _maybeSent = {};

  MealQueueStore get _store => ref.read(mealQueueStoreProvider);

  int? get _userId => ref.read(authControllerProvider).value?.id;

  @override
  OfflineQueueState build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(connectivityProvider, (previous, online) {
      if (previous == false && online) unawaited(flush());
    });
    ref.listen(authControllerProvider.select((a) => a.value?.id), (_, _) {
      _schedule();
      unawaited(flush());
    });
    _restoring = _restore();
    return const OfflineQueueState();
  }

  Future<void> _restore() async {
    final saved = await _store.load();
    if (!ref.mounted) return;
    // After a restart an earlier, unanswered send can't be ruled out.
    _maybeSent.addAll(saved.pending.map((m) => m.clientEventId));
    // Anything queued before the file was read is kept as well.
    state = state.copyWith(
      pending: [...saved.pending, ...state.pending],
      review: [...saved.review, ...state.review],
    );
    _schedule();
    unawaited(flush());
  }

  Future<void> _ready() => _restoring ?? Future<void>.value();

  Future<void> enqueue(PendingMeal meal) async {
    await _ready();
    state = state.copyWith(pending: [...state.pending, meal]);
    await _persist();
    _schedule();
  }

  /// Waits until no flush is in progress.
  Future<void> _settle() async {
    while (state.syncing) {
      await _flushing;
    }
  }

  /// Undo of an offline serve. [RemoveOutcome.removed] only when no send of
  /// this meal can have reached the server (never sent, or answered as not
  /// recorded); [RemoveOutcome.synced] when it left the queue because the
  /// server answered; [RemoveOutcome.unknown] when it was sent (or may have
  /// been, e.g. before a restart) and there is still no answer.
  Future<RemoveOutcome> remove(String clientEventId) async {
    await _ready();
    // A meal being sent may be on the server: wait for its answer instead
    // of dropping it locally.
    await _settle();
    bool queued() => state.pending.any((m) => m.clientEventId == clientEventId);
    if (!queued()) return RemoveOutcome.synced;
    if (_maybeSent.contains(clientEventId)) {
      // An earlier send got no answer for this meal: ask again now.
      await flush();
      await _settle();
      if (!queued()) return RemoveOutcome.synced;
      if (_maybeSent.contains(clientEventId)) return RemoveOutcome.unknown;
    }
    state = state.copyWith(
      pending: [
        for (final m in state.pending)
          if (m.clientEventId != clientEventId) m,
      ],
    );
    await _persist();
    _schedule();
    return RemoveOutcome.removed;
  }

  Future<void> acknowledge(String clientEventId) async {
    await _ready();
    state = state.copyWith(
      review: [
        for (final r in state.review)
          if (r.clientEventId != clientEventId) r,
      ],
    );
    await _persist();
  }

  /// "Log out anyway": this volunteer's unsynced meals and review items are
  /// dropped. Other volunteers' entries on this phone are kept.
  Future<void> discardFor(int userId) async {
    await _ready();
    _maybeSent.removeAll([
      for (final m in state.pending)
        if (m.userId == userId) m.clientEventId,
    ]);
    state = state.copyWith(
      pending: [
        for (final m in state.pending)
          if (m.userId != userId) m,
      ],
      review: [
        for (final r in state.review)
          if (r.userId != userId) r,
      ],
    );
    await _persist();
    _schedule();
  }

  /// Sends the signed-in volunteer's pending meals. Returns how many were
  /// applied. On any failure everything stays queued for the next trigger.
  Future<int> flush() async {
    await _ready();
    if (!ref.mounted) return 0;
    final userId = _userId;
    final batch = state.pendingFor(userId).take(batchSize).toList();
    if (state.syncing || userId == null || batch.isEmpty) return 0;
    state = state.copyWith(syncing: true);
    final finished = Completer<void>();
    _flushing = finished.future;
    // From the moment of sending, the server may have these.
    _maybeSent.addAll(batch.map((m) => m.clientEventId));
    var applied = 0;
    try {
      final results = await ref
          .read(peopleRepositoryProvider)
          .syncMeals(batch);
      if (!ref.mounted) return 0;
      final byId = {for (final r in results) r.clientEventId: r};
      final done = <String>{};
      final toReview = <ReviewItem>[];
      for (final meal in batch) {
        final result = byId[meal.clientEventId];
        if (result == null) {
          _maybeSent.add(meal.clientEventId);
        } else {
          _maybeSent.remove(meal.clientEventId);
        }
        switch (result?.status) {
          case MealSyncStatus.applied:
            applied++;
            done.add(meal.clientEventId);
          case MealSyncStatus.duplicate:
            done.add(meal.clientEventId);
          case MealSyncStatus.conflict || MealSyncStatus.rejected:
            done.add(meal.clientEventId);
            toReview.add(ReviewItem.from(meal, result!));
          case null:
            // No usable answer for this meal: it stays queued.
            break;
        }
      }
      state = state.copyWith(
        pending: [
          for (final m in state.pending)
            if (!done.contains(m.clientEventId)) m,
        ],
        review: [...state.review, ...toReview],
        lastSynced: applied > 0 ? SyncedNotice(applied) : null,
      );
      await _persist();
      if (done.isNotEmpty) unawaited(_refreshList());
    } on AppFailure {
      // No network, expired session or server trouble: kept for later. The
      // server may have applied them before the answer was lost.
      _maybeSent.addAll(batch.map((m) => m.clientEventId));
    } on Object {
      // Anything unexpected is treated the same way, and never rethrown to
      // unawaited callers.
      _maybeSent.addAll(batch.map((m) => m.clientEventId));
    } finally {
      finished.complete();
      if (ref.mounted) {
        state = state.copyWith(syncing: false);
        _schedule();
      }
    }
    return applied;
  }

  /// The list on screen reflects the server after a sync.
  Future<void> _refreshList() async {
    try {
      if (ref.exists(peopleListProvider)) {
        await ref.read(peopleListProvider.notifier).refresh();
      }
    } on Object {
      // The list keeps its local copy; the next refresh catches up.
    }
  }

  Future<void> _persist() => _store.save(
    MealQueueSnapshot(pending: state.pending, review: state.review),
  );

  /// The periodic flush runs only while this volunteer has meals pending.
  void _schedule() {
    if (state.pendingFor(_userId).isEmpty) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(flushEvery, (_) => unawaited(flush()));
    }
  }
}

final offlineQueueProvider =
    NotifierProvider<OfflineQueueController, OfflineQueueState>(
      OfflineQueueController.new,
    );
