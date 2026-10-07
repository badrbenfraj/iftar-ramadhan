import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/storage/device_id.dart';
import '../../../core/utils/uuid.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../people/data/people_repository.dart';
import '../../people/domain/fasting_person.dart';
import '../../people/domain/meal_event.dart';
import '../../people/presentation/people_controller.dart';
import '../domain/qr_payload.dart';

/// The scan → identify → validate → confirm → result workflow.
sealed class ScanStatus {
  const ScanStatus();
}

/// Camera live, waiting for a card.
final class ScanIdle extends ScanStatus {
  const ScanIdle();
}

/// Not on this phone yet: only the ID is known while the server answers.
final class ScanLookingUp extends ScanStatus {
  const ScanLookingUp(this.personId, {this.noCard = false});
  final int personId;
  final bool noCard;
}

/// On this phone: name and meals show now while tonight's status is
/// checked with the server (spec §6.3). Display only, never a verdict.
final class ScanIdentifying extends ScanStatus {
  const ScanIdentifying(this.person, {this.noCard = false});
  final FastingPerson person;
  final bool noCard;
}

/// The code is not a person ID.
final class ScanInvalidCode extends ScanStatus {
  const ScanInvalidCode(this.raw);
  final String raw;
}

/// Valid ID, but nobody with it in the volunteer's region.
final class ScanNotFound extends ScanStatus {
  const ScanNotFound(this.personId);
  final int personId;
}

/// Eligible: has not collected today. Holds pending phone/comment edits.
final class ScanReady extends ScanStatus {
  const ScanReady(this.person, {this.phone, this.comment, this.noCard = false});
  final FastingPerson person;
  final String? phone;
  final String? comment;

  /// Found without a card: the volunteer checks the CIN's last digits.
  final bool noCard;
}

final class ScanConfirming extends ScanStatus {
  const ScanConfirming(
    this.person, {
    required this.clientEventId,
    this.noCard = false,
    this.slow = false,
  });
  final FastingPerson person;

  /// Sent with the confirm. Every retry of this confirm reuses it, so the
  /// server can never record it twice (spec 2A §5.1).
  final String clientEventId;
  final bool noCard;

  /// No answer after [ScanTimings.slowAfter]: "Sending… slow connection".
  final bool slow;
}

final class ScanConfirmed extends ScanStatus {
  const ScanConfirmed(this.person, {this.undoing = false});
  final FastingPerson person;

  /// Undo was tapped and the server hasn't answered yet.
  final bool undoing;
}

/// Already collected today — do not serve again.
final class ScanAlreadyTaken extends ScanStatus {
  const ScanAlreadyTaken(this.person, this.takenAt, {this.servedByName});
  final FastingPerson person;
  final DateTime? takenAt;

  /// Who served it, when the server said (spec 2A §5.3).
  final String? servedByName;
}

/// Network/server error during lookup or confirmation; can be retried.
final class ScanFailed extends ScanStatus {
  const ScanFailed(
    this.failure, {
    required this.personId,
    this.person,
    this.pendingPhone,
    this.pendingComment,
    this.noCard = false,
    this.clientEventId,
  });
  final AppFailure failure;
  final int personId;

  /// Set when the failure happened while confirming this person.
  final FastingPerson? person;
  final String? pendingPhone;
  final String? pendingComment;

  /// The CIN check still applies when this is retried.
  final bool noCard;

  /// The failed confirm's ID; Retry sends it again.
  final String? clientEventId;

  bool get duringConfirm => person != null;
}

enum ScanNoticeKind { undone, undoFailed, undoTooLate, undoNeedsConnection }

/// A one-off message for the volunteer, shown as a snackbar. Every notice is
/// a new object, so the same message twice is shown twice.
class ScanNotice {
  ScanNotice(this.kind, {this.name});
  final ScanNoticeKind kind;

  /// The person, for "Undone. {name} is not marked as served."
  final String? name;
}

class ScanState {
  const ScanState({
    this.status = const ScanIdle(),
    this.notice,
    this.servedCount = 0,
    this.singleMeals = 0,
    this.familyMeals = 0,
  });

  final ScanStatus status;

  /// The latest message for the volunteer (see [ScanNotice]).
  final ScanNotice? notice;

  /// Meals confirmed from this device since the scanner was opened.
  final int servedCount;

  /// Meals handed over this session, for the closing summary.
  final int singleMeals;
  final int familyMeals;

  /// Whether a new camera detection should be processed right now.
  /// Busy or pending-decision states ignore the camera, so a volunteer never
  /// loses an unconfirmed person by accidentally scanning another card.
  bool get acceptsScans => switch (status) {
    ScanIdle() ||
    ScanInvalidCode() ||
    ScanNotFound() ||
    ScanAlreadyTaken() => true,
    ScanConfirmed(:final undoing) => !undoing,
    ScanFailed(:final duringConfirm) => !duringConfirm,
    ScanLookingUp() ||
    ScanIdentifying() ||
    ScanReady() ||
    ScanConfirming() => false,
  };

  ScanState copyWith({
    ScanStatus? status,
    ScanNotice? notice,
    int? servedCount,
    int? singleMeals,
    int? familyMeals,
  }) => ScanState(
    status: status ?? this.status,
    notice: notice ?? this.notice,
    servedCount: servedCount ?? this.servedCount,
    singleMeals: singleMeals ?? this.singleMeals,
    familyMeals: familyMeals ?? this.familyMeals,
  );
}

/// Delays of the confirm flow (spec 2A §5.1, §5.2). Tests shorten them.
class ScanTimings {
  const ScanTimings({
    this.slowAfter = const Duration(seconds: 2),
    this.autoRetryAfter = const Duration(seconds: 3),
    this.undoWindow = const Duration(seconds: 5),
  });

  /// No answer yet: say "Sending… slow connection".
  final Duration slowAfter;

  /// A network or timeout failure is retried once, this long after.
  final Duration autoRetryAfter;

  /// How long the Confirmed band stays (with Undo) before the view clears.
  final Duration undoWindow;
}

final scanTimingsProvider = Provider<ScanTimings>((_) => const ScanTimings());

class ScanController extends Notifier<ScanState> {
  /// A card held in front of the camera is read many times per second; the
  /// same code is ignored while it keeps being seen within this window.
  static const duplicateWindow = Duration(seconds: 4);

  String? _lastRaw;
  DateTime? _lastSeenAt;
  Timer? _resumeTimer;
  Timer? _slowTimer;
  Timer? _autoRetryTimer;

  /// The confirm already retried automatically. One automatic retry per
  /// confirm; after that the volunteer decides.
  String? _autoRetriedEventId;

  DateTime _now() => ref.read(clockProvider)();

  ScanTimings get _timings => ref.read(scanTimingsProvider);

  @override
  ScanState build() {
    ref.onDispose(() {
      _resumeTimer?.cancel();
      _slowTimer?.cancel();
      _autoRetryTimer?.cancel();
    });
    return const ScanState();
  }

  /// Camera callback.
  Future<void> onDetected(String? raw) async {
    if (!state.acceptsScans || raw == null) return;
    final now = _now();
    final isRepeat =
        raw == _lastRaw &&
        _lastSeenAt != null &&
        now.difference(_lastSeenAt!) < duplicateWindow;
    _lastSeenAt = now;
    if (isRepeat) return;
    _lastRaw = raw;
    await _handle(raw);
  }

  bool get _busy => switch (state.status) {
    ScanLookingUp() || ScanIdentifying() || ScanConfirming() => true,
    _ => false,
  };

  /// Looks up an ID given as text, bypassing the duplicate-scan filter. No
  /// screen calls it today (Find covers damaged cards); it is the entry point
  /// the controller tests drive.
  Future<void> submitManual(String input) async {
    if (_busy) return;
    // A failed confirm must be resolved (retry or skip) first.
    if (state.status case ScanFailed(duringConfirm: true)) return;
    _lastRaw = input.trim();
    _lastSeenAt = _now();
    await _handle(input);
  }

  /// "Find someone without a card" (spec §4.7): same flow, plus the CIN check.
  Future<void> pickWithoutCard(int personId) async {
    if (_busy) return;
    // A failed confirm must be resolved (retry or skip) first.
    if (state.status case ScanFailed(duringConfirm: true)) return;
    _resumeTimer?.cancel();
    _lastRaw = '$personId';
    _lastSeenAt = _now();
    await _lookup(personId, noCard: true);
  }

  /// Back from another screen (Details, the registration form): looks the
  /// shown person up again when something there may have changed the answer.
  /// A pending person is only re-checked when the list says they were served
  /// meanwhile, so contact edits made here survive a look at Details. An
  /// unknown card is looked up again (it may have just been registered).
  Future<void> refreshCurrent() async {
    switch (state.status) {
      case ScanReady(:final person, :final noCard):
        if (_cached(person.id)?.isMealTakenToday(_now()) != true) return;
        _resumeTimer?.cancel();
        await _lookup(person.id, noCard: noCard);
      case ScanNotFound(:final personId):
        _resumeTimer?.cancel();
        await _lookup(personId);
      default:
        return;
    }
  }

  Future<void> _handle(String raw) async {
    _resumeTimer?.cancel();
    switch (QrPayload.parse(raw)) {
      case InvalidQr(:final raw):
        _set(ScanInvalidCode(raw));
      case PersonQr(:final personId):
        await _lookup(personId);
    }
  }

  Future<void> _lookup(int personId, {bool noCard = false}) async {
    final cached = _cached(personId);
    _set(
      cached == null
          ? ScanLookingUp(personId, noCard: noCard)
          : ScanIdentifying(cached, noCard: noCard),
    );
    try {
      final region = requireRegion(ref);
      final person = await ref
          .read(peopleRepositoryProvider)
          .get(region.id, personId);
      if (!_stillLookingUp(personId)) return;
      ref.read(peopleListProvider.notifier).upsert(person);
      // The verdict always comes from the server response.
      final meal = person.todayMealAt(_now());
      _set(
        person.isMealTakenToday(_now())
            ? ScanAlreadyTaken(
                person,
                meal?.servedAt ?? person.lastTakenMeal,
                servedByName: meal?.servedByName,
              )
            : ScanReady(person, noCard: noCard),
      );
    } on NotFoundFailure {
      if (_stillLookingUp(personId)) _set(ScanNotFound(personId));
    } catch (e) {
      if (_stillLookingUp(personId)) {
        _set(
          ScanFailed(toAppFailure(e), personId: personId, noCard: noCard),
        );
      }
    }
  }

  FastingPerson? _cached(int id) {
    for (final p
        in ref.read(peopleListProvider).value ?? const <FastingPerson>[]) {
      if (p.id == id) return p;
    }
    return null;
  }

  bool _stillLookingUp(int id) =>
      ref.mounted &&
      switch (state.status) {
        ScanLookingUp(:final personId) => personId == id,
        ScanIdentifying(:final person) => person.id == id,
        _ => false,
      };

  /// Pending phone/comment edits, sent with the confirmation.
  void editContact({required String phone, required String comment}) {
    if (state.status case ScanReady(:final person, :final noCard)) {
      _set(ScanReady(person, phone: phone, comment: comment, noCard: noCard));
    }
  }

  /// "Confirm & scan next", and Retry after a failed confirm.
  Future<void> confirm() async {
    final (person, phone, comment, noCard, retryOf) = switch (state.status) {
      ScanReady(:final person, :final phone, :final comment, :final noCard) => (
        person,
        phone,
        comment,
        noCard,
        null,
      ),
      ScanFailed(
        :final person?,
        :final pendingPhone,
        :final pendingComment,
        :final noCard,
        :final clientEventId,
      ) =>
        (person, pendingPhone, pendingComment, noCard, clientEventId),
      _ => (null, null, null, false, null),
    };
    if (person == null) return;

    _autoRetryTimer?.cancel();
    // A retry repeats the same confirm; a new tap is a new one.
    final eventId = retryOf ?? newUuidV4();
    _set(ScanConfirming(person, clientEventId: eventId, noCard: noCard));
    _slowTimer?.cancel();
    _slowTimer = Timer(_timings.slowAfter, () {
      if (!ref.mounted) return;
      if (state.status case ScanConfirming(
        clientEventId: final id,
        :final person,
        :final noCard,
      ) when id == eventId) {
        _set(
          ScanConfirming(
            person,
            clientEventId: eventId,
            noCard: noCard,
            slow: true,
          ),
        );
      }
    });

    try {
      final region = requireRegion(ref);
      final deviceId = await ref.read(deviceIdProvider.future);
      final updated = await ref
          .read(peopleRepositoryProvider)
          .confirmMeal(
            region.id,
            person.id,
            phone: phone,
            comment: comment,
            clientEventId: eventId,
            deviceId: deviceId,
          );
      _slowTimer?.cancel();
      if (!ref.mounted) return;
      _onConfirmed(updated);
    } on MealAlreadyTakenFailure catch (e) {
      _slowTimer?.cancel();
      if (!ref.mounted) return;
      // The server answers a retry of our own confirm with 200, so a 409 is
      // always a real earlier meal: another phone, or before a Skip.
      _set(ScanAlreadyTaken(person, e.takenAt, servedByName: e.servedByName));
    } catch (e) {
      _slowTimer?.cancel();
      if (!ref.mounted) return;
      final failure = toAppFailure(e);
      _set(
        ScanFailed(
          failure,
          personId: person.id,
          person: person,
          pendingPhone: phone,
          pendingComment: comment,
          noCard: noCard,
          clientEventId: eventId,
        ),
      );
      final network = failure is NetworkFailure || failure is TimeoutFailure;
      if (network && _autoRetriedEventId != eventId) {
        _autoRetriedEventId = eventId;
        _autoRetryTimer = Timer(_timings.autoRetryAfter, () {
          if (!ref.mounted) return;
          if (state.status case ScanFailed(
            clientEventId: final id,
          ) when id == eventId) {
            unawaited(confirm());
          }
        });
      }
    }
  }

  void _onConfirmed(FastingPerson person) {
    ref.read(peopleListProvider.notifier).upsert(person);
    state = state.copyWith(
      status: ScanConfirmed(person),
      servedCount: state.servedCount + 1,
      singleMeals: state.singleMeals + person.singleMeal,
      familyMeals: state.familyMeals + person.familyMeal,
    );
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_timings.undoWindow, () {
      if (ref.mounted && state.status is ScanConfirmed) {
        _set(const ScanIdle());
      }
    });
  }

  /// "Undo · 5" on the Confirmed band (spec 2A §5.2).
  Future<void> undo() async {
    final status = state.status;
    if (status is! ScanConfirmed || status.undoing) return;
    final meal = status.person.todayMeal;
    if (meal == null) return;
    _resumeTimer?.cancel();
    _set(ScanConfirmed(status.person, undoing: true));
    final notice = await _revoke(meal.eventId, status.person);
    if (!ref.mounted) return;
    final undone = notice.kind == ScanNoticeKind.undone;
    final p = status.person;
    state = state.copyWith(
      status: const ScanIdle(),
      notice: notice,
      servedCount: undone ? state.servedCount - 1 : null,
      singleMeals: undone ? state.singleMeals - p.singleMeal : null,
      familyMeals: undone ? state.familyMeals - p.familyMeal : null,
    );
    // The card still in front of the lens is not re-read at once.
    _lastSeenAt = _now();
  }

  /// History → "Undo tonight's meal" on an Already-served sheet: undo, then
  /// look the person up again so the sheet shows the new answer.
  Future<void> undoFromHistory(FastingPerson person, MealEvent meal) async {
    if (state.status is! ScanAlreadyTaken) return;
    final notice = await _revoke(meal.eventId, person);
    if (!ref.mounted) return;
    state = state.copyWith(notice: notice);
    if (notice.kind == ScanNoticeKind.undone) await _lookup(person.id);
  }

  Future<ScanNotice> _revoke(String eventId, FastingPerson person) async {
    try {
      final updated = await ref
          .read(peopleRepositoryProvider)
          .revokeMeal(eventId);
      if (ref.mounted) ref.read(peopleListProvider.notifier).upsert(updated);
      return ScanNotice(ScanNoticeKind.undone, name: person.fullName);
    } on UndoRefusedFailure catch (e) {
      return ScanNotice(
        e.tooLate ? ScanNoticeKind.undoTooLate : ScanNoticeKind.undoFailed,
      );
    } on NetworkFailure {
      return ScanNotice(ScanNoticeKind.undoNeedsConnection);
    } on TimeoutFailure {
      return ScanNotice(ScanNoticeKind.undoNeedsConnection);
    } on Object {
      return ScanNotice(ScanNoticeKind.undoFailed);
    }
  }

  Future<void> retry() async {
    final status = state.status;
    if (status is! ScanFailed) return;
    if (status.duringConfirm) {
      await confirm();
    } else {
      await _lookup(status.personId, noCard: status.noCard);
    }
  }

  /// Back to the camera ("Scan next" / "Skip"). The card that is probably
  /// still in front of the lens is not re-read immediately.
  void scanNext() {
    _resumeTimer?.cancel();
    _autoRetryTimer?.cancel();
    _lastSeenAt = _now();
    _set(const ScanIdle());
  }

  void _set(ScanStatus status) => state = state.copyWith(status: status);
}

final scanControllerProvider =
    NotifierProvider.autoDispose<ScanController, ScanState>(ScanController.new);
