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

final class ScanLookingUp extends ScanStatus {
  const ScanLookingUp(this.personId);
  final int personId;
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
  const ScanReady(this.person, {this.phone, this.comment});
  final FastingPerson person;
  final String? phone;
  final String? comment;
}

final class ScanConfirming extends ScanStatus {
  const ScanConfirming(this.person);
  final FastingPerson person;
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
  });
  final AppFailure failure;
  final int personId;

  /// Set when the failure happened while confirming this person.
  final FastingPerson? person;
  final String? pendingPhone;
  final String? pendingComment;

  bool get duringConfirm => person != null;
}

class ScanState {
  const ScanState({this.status = const ScanIdle(), this.servedCount = 0});

  final ScanStatus status;

  /// Meals confirmed from this device since the scanner was opened.
  final int servedCount;

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
    ScanLookingUp() || ScanReady() || ScanConfirming() => false,
  };

  ScanState copyWith({ScanStatus? status, int? servedCount}) => ScanState(
    status: status ?? this.status,
    servedCount: servedCount ?? this.servedCount,
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
  bool _confirmMayHaveReachedServer = false;

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

  /// Manual ID entry (damaged card, no camera permission).
  Future<void> submitManual(String input) async {
    if (state.status is ScanLookingUp || state.status is ScanConfirming) return;
    _lastRaw = input.trim();
    _lastSeenAt = _now();
    await _handle(input);
  }

  Future<void> _handle(String raw) async {
    _resumeTimer?.cancel();
    _confirmMayHaveReachedServer = false;
    switch (QrPayload.parse(raw)) {
      case InvalidQr(:final raw):
        _set(ScanInvalidCode(raw));
      case PersonQr(:final personId):
        await _lookup(personId);
    }
  }

  Future<void> _lookup(int personId) async {
    _set(ScanLookingUp(personId));
    try {
      final region = requireRegion(ref);
      final person = await ref
          .read(peopleRepositoryProvider)
          .get(region.id, personId);
      if (!_stillLookingUp(personId)) return;
      ref.read(peopleListProvider.notifier).upsert(person);
      _set(
        person.isMealTakenToday(_now())
            ? ScanAlreadyTaken(person, person.lastTakenMeal)
            : ScanReady(person),
      );
    } on NotFoundFailure {
      if (_stillLookingUp(personId)) _set(ScanNotFound(personId));
    } catch (e) {
      if (_stillLookingUp(personId)) {
        _set(ScanFailed(toAppFailure(e), personId: personId));
      }
    }
  }

  bool _stillLookingUp(int id) =>
      ref.mounted &&
      switch (state.status) {
        ScanLookingUp(:final personId) => personId == id,
        _ => false,
      };

  /// Pending phone/comment edits, sent with the confirmation.
  void editContact({required String phone, required String comment}) {
    if (state.status case ScanReady(:final person)) {
      _set(ScanReady(person, phone: phone, comment: comment));
    }
  }

  /// "Confirm & scan next".
  Future<void> confirm() async {
    final (person, phone, comment) = switch (state.status) {
      ScanReady(:final person, :final phone, :final comment) => (
        person,
        phone,
        comment,
      ),
      ScanFailed(:final person?, :final pendingPhone, :final pendingComment) =>
        (person, pendingPhone, pendingComment),
      _ => (null, null, null),
    };
    if (person == null) return;

    _set(ScanConfirming(person));
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
          _confirmMayHaveReachedServer &&
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
        _set(ScanAlreadyTaken(person, takenAt));
      }
    } catch (e) {
      if (!ref.mounted) return;
      final failure = toAppFailure(e);
      // The request may have been applied even though we got no answer.
      if (failure is NetworkFailure || failure is TimeoutFailure) {
        _confirmMayHaveReachedServer = true;
      }
      _set(
        ScanFailed(
          failure,
          personId: person.id,
          person: person,
          pendingPhone: phone,
          pendingComment: comment,
        ),
      );
    }
  }

  void _onConfirmed(FastingPerson person) {
    _confirmMayHaveReachedServer = false;
    ref.read(peopleListProvider.notifier).upsert(person);
    state = state.copyWith(
      status: ScanConfirmed(person),
      servedCount: state.servedCount + 1,
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
      await _lookup(status.personId);
    }
  }

  /// Back to the camera ("Scan next" / "Skip"). The card that is probably
  /// still in front of the lens is not re-read immediately.
  void scanNext() {
    _resumeTimer?.cancel();
    _confirmMayHaveReachedServer = false;
    _lastSeenAt = _now();
    _set(const ScanIdle());
  }

  void _set(ScanStatus status) => state = state.copyWith(status: status);
}

final scanControllerProvider =
    NotifierProvider.autoDispose<ScanController, ScanState>(ScanController.new);
