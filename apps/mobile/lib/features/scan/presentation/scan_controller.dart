import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../people/data/people_repository.dart';
import '../../people/domain/fasting_person.dart';
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
  const ScanConfirming(this.person, {this.noCard = false});
  final FastingPerson person;
  final bool noCard;
}

final class ScanConfirmed extends ScanStatus {
  const ScanConfirmed(this.person);
  final FastingPerson person;
}

/// Already collected today — do not serve again.
final class ScanAlreadyTaken extends ScanStatus {
  const ScanAlreadyTaken(this.person, this.takenAt);
  final FastingPerson person;
  final DateTime? takenAt;
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
  });
  final AppFailure failure;
  final int personId;

  /// Set when the failure happened while confirming this person.
  final FastingPerson? person;
  final String? pendingPhone;
  final String? pendingComment;

  /// The CIN check still applies when this is retried.
  final bool noCard;

  bool get duringConfirm => person != null;
}

class ScanState {
  const ScanState({
    this.status = const ScanIdle(),
    this.servedCount = 0,
    this.singleMeals = 0,
    this.familyMeals = 0,
  });

  final ScanStatus status;

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
    ScanAlreadyTaken() ||
    ScanConfirmed() => true,
    ScanFailed(:final duringConfirm) => !duringConfirm,
    ScanLookingUp() ||
    ScanIdentifying() ||
    ScanReady() ||
    ScanConfirming() => false,
  };

  ScanState copyWith({
    ScanStatus? status,
    int? servedCount,
    int? singleMeals,
    int? familyMeals,
  }) => ScanState(
    status: status ?? this.status,
    servedCount: servedCount ?? this.servedCount,
    singleMeals: singleMeals ?? this.singleMeals,
    familyMeals: familyMeals ?? this.familyMeals,
  );
}

class ScanController extends Notifier<ScanState> {
  /// A card held in front of the camera is read many times per second; the
  /// same code is ignored while it keeps being seen within this window.
  static const duplicateWindow = Duration(seconds: 4);

  /// How long the "Meal confirmed" result stays before scanning resumes.
  static const confirmedHold = Duration(milliseconds: 1600);

  /// A 409 right after a failed confirm (e.g. timeout after the server
  /// committed) is our own confirmation, not a second pickup.
  static const _ownConfirmationWindow = Duration(minutes: 3);

  String? _lastRaw;
  DateTime? _lastSeenAt;
  Timer? _resumeTimer;

  /// The person whose last confirm ended without an answer, so the server may
  /// have recorded it. Only a 409 for this same person, soon after, and only
  /// while still in the failed-confirm → retry flow, is our own write. Skip or
  /// any lookup leaves that flow and clears the mark: from then on a 409 is a
  /// real second pickup, even for the same person.
  int? _uncertainConfirmPersonId;
  DateTime? _uncertainConfirmAt;

  DateTime _now() => ref.read(clockProvider)();

  @override
  ScanState build() {
    ref.onDispose(() => _resumeTimer?.cancel());
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
    // An uncertain confirm must be resolved (retry or skip) first: a new
    // lookup would forget that our own write may already be on the server.
    if (state.status case ScanFailed(duringConfirm: true)) return;
    _lastRaw = input.trim();
    _lastSeenAt = _now();
    await _handle(input);
  }

  /// "Find someone without a card" (spec §4.7): same flow, plus the CIN check.
  Future<void> pickWithoutCard(int personId) async {
    if (_busy) return;
    // An uncertain confirm must be resolved (retry or skip) first.
    if (state.status case ScanFailed(duringConfirm: true)) return;
    _resumeTimer?.cancel();
    _clearUncertain();
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
    _clearUncertain();
    switch (QrPayload.parse(raw)) {
      case InvalidQr(:final raw):
        _set(ScanInvalidCode(raw));
      case PersonQr(:final personId):
        await _lookup(personId);
    }
  }

  Future<void> _lookup(int personId, {bool noCard = false}) async {
    _clearUncertain(); // a lookup is outside the failed-confirm flow
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
      _set(
        person.isMealTakenToday(_now())
            ? ScanAlreadyTaken(person, person.lastTakenMeal)
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

  /// "Confirm & scan next".
  Future<void> confirm() async {
    final (person, phone, comment, noCard) = switch (state.status) {
      ScanReady(:final person, :final phone, :final comment, :final noCard) => (
        person,
        phone,
        comment,
        noCard,
      ),
      ScanFailed(
        :final person?,
        :final pendingPhone,
        :final pendingComment,
        :final noCard,
      ) =>
        (person, pendingPhone, pendingComment, noCard),
      _ => (null, null, null, false),
    };
    if (person == null) return;

    _set(ScanConfirming(person, noCard: noCard));
    try {
      final region = requireRegion(ref);
      final updated = await ref
          .read(peopleRepositoryProvider)
          .confirmMeal(region.id, person.id, phone: phone, comment: comment);
      if (!ref.mounted) return;
      _onConfirmed(updated);
    } on MealAlreadyTakenFailure catch (e) {
      if (!ref.mounted) return;
      final takenAt = e.takenAt;
      final ours =
          _isUncertain(person.id) &&
          takenAt != null &&
          _now().difference(takenAt).abs() < _ownConfirmationWindow;
      if (ours) {
        _onConfirmed(
          person.copyWith(
            lastTakenMeal: takenAt,
            mealTakenTodayFromServer: true,
          ),
        );
      } else {
        if (_uncertainConfirmPersonId == person.id) _clearUncertain();
        _set(ScanAlreadyTaken(person, takenAt));
      }
    } catch (e) {
      if (!ref.mounted) return;
      final failure = toAppFailure(e);
      // The request may have been applied even though we got no answer.
      if (failure is NetworkFailure || failure is TimeoutFailure) {
        _uncertainConfirmPersonId = person.id;
        _uncertainConfirmAt = _now();
      }
      _set(
        ScanFailed(
          failure,
          personId: person.id,
          person: person,
          pendingPhone: phone,
          pendingComment: comment,
          noCard: noCard,
        ),
      );
    }
  }

  bool _isUncertain(int personId) {
    final at = _uncertainConfirmAt;
    if (_uncertainConfirmPersonId != personId || at == null) return false;
    if (_now().difference(at).abs() >= _ownConfirmationWindow) {
      _clearUncertain();
      return false;
    }
    return true;
  }

  void _clearUncertain() {
    _uncertainConfirmPersonId = null;
    _uncertainConfirmAt = null;
  }

  void _onConfirmed(FastingPerson person) {
    if (_uncertainConfirmPersonId == person.id) _clearUncertain();
    ref.read(peopleListProvider.notifier).upsert(person);
    state = state.copyWith(
      status: ScanConfirmed(person),
      servedCount: state.servedCount + 1,
      singleMeals: state.singleMeals + person.singleMeal,
      familyMeals: state.familyMeals + person.familyMeal,
    );
    _resumeTimer?.cancel();
    _resumeTimer = Timer(confirmedHold, () {
      if (ref.mounted && state.status is ScanConfirmed) {
        _set(const ScanIdle());
      }
    });
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
    _clearUncertain();
    _lastSeenAt = _now();
    _set(const ScanIdle());
  }

  void _set(ScanStatus status) => state = state.copyWith(status: status);
}

final scanControllerProvider =
    NotifierProvider.autoDispose<ScanController, ScanState>(ScanController.new);
