import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/meal_status_badge.dart';
import '../../people/domain/fasting_person.dart';
import '../../people/presentation/person_widgets.dart';
import 'scan_controller.dart';

/// Bottom card showing the outcome of the current scan.
class ScanResultPanel extends ConsumerWidget {
  const ScanResultPanel({
    super.key,
    required this.status,
    required this.onManualEntry,
  });

  final ScanStatus status;
  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(scanControllerProvider.notifier);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: KeyedSubtree(
        key: ValueKey(_keyFor(status)),
        child: _content(context, controller),
      ),
    );
  }

  static String _keyFor(ScanStatus s) => switch (s) {
    ScanReady(:final person) => 'ready-${person.id}',
    ScanConfirming(:final person) => 'ready-${person.id}', // same card
    ScanConfirmed(:final person) => 'done-${person.id}',
    ScanAlreadyTaken(:final person) => 'taken-${person.id}',
    ScanLookingUp(:final personId) => 'lookup-$personId',
    ScanIdentifying(:final person) => 'ready-${person.id}',
    ScanNotFound(:final personId) => 'missing-$personId',
    ScanInvalidCode(:final raw) => 'invalid-$raw',
    ScanFailed(:final personId) => 'failed-$personId',
    ScanIdle() => 'idle',
  };

  Widget _content(BuildContext context, ScanController controller) {
    switch (status) {
      case ScanIdle():
        return const _Hint('Align the QR card inside the frame');

      case ScanLookingUp(:final personId):
        return _Panel(
          tone: _Tone.neutral,
          icon: Icons.search_rounded,
          title: 'Looking up #$personId…',
          busy: true,
        );

      case ScanIdentifying(:final person):
        return _PersonPanel(
          person: person,
          tone: _Tone.neutral,
          headline: 'Checking…',
          busy: true,
        );

      case ScanInvalidCode(:final raw):
        return _Panel(
          tone: _Tone.warning,
          icon: Icons.qr_code_2_rounded,
          title: 'Invalid QR code',
          message: raw.isEmpty
              ? 'The code could not be read.'
              : 'This code does not contain a person ID.',
          actions: [
            _Action.primary('Scan again', controller.scanNext),
            _Action.secondary('Enter ID', onManualEntry),
          ],
        );

      case ScanNotFound(:final personId):
        return _Panel(
          tone: _Tone.warning,
          icon: Icons.person_search_rounded,
          title: 'Person #$personId not found',
          message: 'Nobody with this ID is registered in your region.',
          actions: [
            _Action.primary('Scan again', controller.scanNext),
            _Action.secondary(
              'Register',
              () => context.go('/add?id=$personId'),
            ),
          ],
        );

      case ScanReady(:final person, :final phone, :final comment):
        return _PersonPanel(
          person: person,
          tone: _Tone.go,
          headline: 'Can collect today',
          phone: phone ?? person.phone,
          comment: comment ?? person.comment,
          onEditContact: () async {
            final result = await showContactEditor(
              context,
              phone: phone ?? person.phone,
              comment: comment ?? person.comment,
            );
            if (result != null) {
              controller.editContact(
                phone: result.phone,
                comment: result.comment,
              );
            }
          },
          actions: [
            _Action.primary(
              'Confirm & scan next',
              controller.confirm,
              icon: Icons.restaurant_rounded,
            ),
            _Action.secondary('Skip', controller.scanNext),
            _Action.secondary(
              'Details',
              () => context.push('/people/${person.id}'),
            ),
          ],
        );

      case ScanConfirming(:final person):
        return _PersonPanel(
          person: person,
          tone: _Tone.go,
          headline: 'Confirming…',
          busy: true,
        );

      case ScanConfirmed(:final person):
        return _Panel(
          tone: _Tone.success,
          icon: Icons.check_circle_rounded,
          title: 'Meal confirmed',
          message:
              '${isolate(person.fullName)}\n'
              'Hand over ${person.singleMeal} single · '
              '${person.familyMeal} family',
        );

      case ScanAlreadyTaken(:final person, :final takenAt):
        return _PersonPanel(
          person: person,
          tone: _Tone.stop,
          headline: takenAt == null
              ? 'Already collected today'
              : 'Already collected today at ${formatTime(takenAt)}',
          actions: [
            _Action.primary(
              'Scan next',
              controller.scanNext,
              icon: Icons.qr_code_scanner_rounded,
            ),
            _Action.secondary(
              'History',
              () => showMealHistory(context, person),
            ),
            _Action.secondary(
              'Details',
              () => context.push('/people/${person.id}'),
            ),
          ],
        );

      case ScanFailed(:final failure, :final duringConfirm):
        final offline = failure is NetworkFailure || failure is TimeoutFailure;
        return _Panel(
          tone: _Tone.warning,
          icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
          title: offline
              ? 'No connection'
              : failure is ServerFailure
              ? 'Server error'
              : 'Something went wrong',
          message: duringConfirm
              ? '${failure.message}\nThe meal is not confirmed until the '
                    'server answers — retry, do not serve twice.'
              : failure.message,
          actions: [
            _Action.primary('Retry', controller.retry, icon: Icons.refresh),
            _Action.secondary('Cancel', controller.scanNext),
          ],
        );
    }
  }
}

enum _Tone { neutral, go, success, stop, warning }

extension on _Tone {
  Color get color => switch (this) {
    _Tone.neutral => AppColors.night,
    _Tone.go => AppColors.teal,
    _Tone.success => AppColors.success,
    _Tone.stop => AppColors.danger,
    _Tone.warning => AppColors.warning,
  };

  Color get soft => switch (this) {
    _Tone.neutral => AppColors.ivory,
    _Tone.go => const Color(0xFFE0F6F2),
    _Tone.success => AppColors.successSoft,
    _Tone.stop => AppColors.dangerSoft,
    _Tone.warning => AppColors.warningSoft,
  };
}

class _Action {
  const _Action._(this.label, this.onPressed, this.primary, this.icon);

  factory _Action.primary(
    String label,
    VoidCallback onPressed, {
    IconData? icon,
  }) => _Action._(label, onPressed, true, icon);

  factory _Action.secondary(String label, VoidCallback onPressed) =>
      _Action._(label, onPressed, false, null);

  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final IconData? icon;
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.nightlight_round, color: AppColors.gold, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(text, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.tone, required this.child});

  final _Tone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card + 4),
        border: Border(top: BorderSide(color: tone.color, width: 6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.lg,
        AppSpacing.gutter,
        AppSpacing.gutter,
      ),
      child: child,
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.tone,
    required this.icon,
    required this.title,
    this.message,
    this.actions = const [],
    this.busy = false,
  });

  final _Tone tone;
  final IconData icon;
  final String title;
  final String? message;
  final List<_Action> actions;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      tone: tone,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tone.soft,
                  shape: BoxShape.circle,
                ),
                child: busy
                    ? SizedBox.square(
                        dimension: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: tone.color,
                        ),
                      )
                    : Icon(icon, color: tone.color, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: tone.color,
                  ),
                ),
              ),
            ],
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: const TextStyle(fontSize: 15)),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Actions(actions: actions, tone: tone),
          ],
        ],
      ),
    );
  }
}

class _PersonPanel extends StatelessWidget {
  const _PersonPanel({
    required this.person,
    required this.tone,
    required this.headline,
    this.phone,
    this.comment,
    this.onEditContact,
    this.actions = const [],
    this.busy = false,
  });

  final FastingPerson person;
  final _Tone tone;
  final String headline;
  final String? phone;
  final String? comment;
  final VoidCallback? onEditContact;
  final List<_Action> actions;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final taken = tone == _Tone.stop;
    return _Sheet(
      tone: tone,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                taken ? Icons.block_rounded : Icons.verified_rounded,
                color: tone.color,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  headline,
                  style: TextStyle(
                    color: tone.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              MealStatusBadge(takenToday: taken, large: true),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            person.fullName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          Text(
            [
              '#${person.id}',
              if (person.cin != null) 'CIN ${person.cin}',
            ].join(' · '),
            style: const TextStyle(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          MealAllotment(person: person),
          if (phone != null || comment != null || onEditContact != null) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: onEditContact,
              borderRadius: BorderRadius.circular(AppRadii.chip),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 16,
                      color: AppColors.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [phone ?? 'No phone', ?comment].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.inkMuted),
                      ),
                    ),
                    if (onEditContact != null)
                      const Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: AppColors.tealDeep,
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (busy) ...[
            const SizedBox(height: AppSpacing.lg),
            const LinearProgressIndicator(minHeight: 4),
          ] else if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Actions(actions: actions, tone: tone),
          ],
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.actions, required this.tone});

  final List<_Action> actions;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final primary = actions.where((a) => a.primary);
    final secondary = actions.where((a) => !a.primary).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in primary)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: tone == _Tone.stop
                  ? AppColors.night
                  : tone.color,
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: a.onPressed,
            icon: Icon(a.icon ?? Icons.arrow_forward_rounded),
            label: Text(a.label),
          ),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final a in secondary)
                Expanded(
                  child: TextButton(
                    onPressed: a.onPressed,
                    child: Text(a.label),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
