import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/version_repository.dart';
import '../domain/app_version_info.dart';

class UpdateState {
  const UpdateState({
    this.status = UpdateStatus.upToDate,
    this.info = const AppVersionInfo(),
    this.promptDismissed = false,
  });

  final UpdateStatus status;
  final AppVersionInfo info;

  /// "Later" was tapped on the optional prompt during this app run.
  final bool promptDismissed;

  bool get showOptionalPrompt =>
      status == UpdateStatus.optional && !promptDismissed;
}

/// Asks the backend for the current release at startup (and on resume when
/// the last answer is old). The check never blocks or fails the app: offline
/// or broken answers leave the volunteer where they are. Only an explicit
/// "below minimumVersion" blocks normal use.
class UpdateController extends Notifier<UpdateState> {
  static const _staleAfter = Duration(hours: 1);
  static const _timeout = Duration(seconds: 8);

  DateTime? _checkedAt;
  bool _inFlight = false;

  @override
  UpdateState build() => const UpdateState();

  Future<void> check() async {
    // Releases are APKs. The web version is updated on the server: the next
    // page load gets it.
    if (kIsWeb || _inFlight) return;
    _inFlight = true;
    try {
      final installed = await ref.read(installedVersionProvider.future);
      final info = await ref
          .read(versionRepositoryProvider)
          .fetch()
          .timeout(_timeout);
      _checkedAt = ref.read(clockProvider)();
      final status = decideUpdate(installedVersion: installed, info: info);
      state = UpdateState(
        status: status,
        info: info,
        // The same newer version stays dismissed; a different one asks again.
        promptDismissed:
            state.promptDismissed &&
            state.info.latestVersion == info.latestVersion,
      );
    } catch (_) {
      // Keep the last known answer (a required update stays required).
    } finally {
      _inFlight = false;
    }
  }

  Future<void> checkIfStale() async {
    final at = _checkedAt;
    if (at != null && ref.read(clockProvider)().difference(at) < _staleAfter) {
      return;
    }
    await check();
  }

  void dismissPrompt() => state = UpdateState(
    status: state.status,
    info: state.info,
    promptDismissed: true,
  );

  /// Opens the server's `/download` page in the browser; false if it failed.
  Future<bool> openDownloadPage() async {
    final base = Uri.parse(ref.read(appConfigProvider).apiUrl);
    try {
      return await ref.read(urlOpenerProvider)(
        base.resolve(state.info.downloadPageUrl),
      );
    } catch (_) {
      return false;
    }
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
