import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/failure_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/masking.dart';
import '../../../core/widgets/brand.dart';
import '../../../core/widgets/hand_over_tiles.dart';
import '../../../core/widgets/seal.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../people/domain/fasting_person.dart';
import '../../people/presentation/person_widgets.dart';
import 'scan_controller.dart';

/// Bottom of the scan screen. The band and seal give the verdict at a
/// glance; the body says what to do next (spec §4.6).
class ScanResultPanel extends ConsumerWidget {
  const ScanResultPanel({
    super.key,
    required this.status,
    required this.onFindWithoutCard,
  });

  final ScanStatus status;
  final VoidCallback onFindWithoutCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      // Only the current sheet is ever shown: an outgoing sheet would keep
      // the previous person's opposite verdict (and a live Confirm) on screen.
      layoutBuilder: (current, _) => Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: current ?? const SizedBox.shrink(),
      ),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: KeyedSubtree(
        key: ValueKey(_keyFor(status)),
        child: _content(context, ref),
      ),
    );
  }

  /// Identifying → Ready keeps the same key so the sheet updates in place.
  static String _keyFor(ScanStatus s) => switch (s) {
    ScanIdle() => 'idle',
    ScanLookingUp(:final personId) => 'lookup-$personId',
    ScanIdentifying(:final person) => 'ready-${person.id}',
    ScanReady(:final person) => 'ready-${person.id}',
    ScanConfirming(:final person) => 'ready-${person.id}',
    ScanConfirmed(:final person) => 'done-${person.id}',
    ScanAlreadyTaken(:final person) => 'taken-${person.id}',
    ScanNotFound(:final personId) => 'missing-$personId',
    ScanInvalidCode(:final raw) => 'invalid-$raw',
    ScanFailed(:final personId) => 'failed-$personId',
  };

  Widget _content(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final controller = ref.read(scanControllerProvider.notifier);
    final problem = Seal(SealKind.problem, semanticLabel: l.sealProblem);
    final checking = Seal(SealKind.checking, semanticLabel: l.sealChecking);

    switch (status) {
      case ScanIdle():
        // Only the camera while waiting: people without a card are served
        // from the people list, outside the scanner.
        return const SizedBox.shrink();

      case ScanLookingUp(:final personId):
        return _Sheet(
          band: _Band(color: AppPalette.waitBand, seal: checking, title: l.lookingUp(personId), small: true),
          body: const [_WaitBar()],
        );

      case ScanIdentifying(:final person, :final noCard):
        return _Sheet(
          band: _Band(
            color: AppPalette.waitBand,
            seal: checking,
            title: person.fullName,
            subtitle: l.checkingStatus,
            small: true,
          ),
          body: [
            _PersonMeta(person),
            _Label(l.handOver),
            HandOverTiles(person: person),
            if (noCard) _NoCardCheck(person),
            const _WaitBar(),
          ],
        );

      case ScanReady(:final person, :final phone, :final comment, :final noCard):
        return _ready(
          context,
          controller,
          person,
          phone: phone ?? person.phone,
          comment: comment ?? person.comment,
          noCard: noCard,
          busy: false,
        );

      case ScanConfirming(:final person, :final noCard, :final slow):
        return _ready(
          context,
          controller,
          person,
          phone: person.phone,
          comment: person.comment,
          noCard: noCard,
          busy: true,
          slow: slow,
        );

      case ScanConfirmed(:final person, :final undoing):
        return _DoneBand(
          person: person,
          undoing: undoing,
          undoWindow: ref.read(scanTimingsProvider).undoWindow,
          // No meal ID (older backend): nothing the server could undo.
          onUndo: person.todayMeal == null ? null : controller.undo,
        );

      case ScanAlreadyTaken(:final person, :final takenAt, :final servedByName):
        final time = takenAt == null ? null : ltr(formatTime(takenAt));
        return _Sheet(
          background: c.claySoft,
          band: _Band(
            color: AppPalette.pausedBand,
            seal: Seal(SealKind.served, semanticLabel: l.sealServed),
            title: MealStatusWords.taken,
            subtitle: l.alreadyServedTonight,
            trailing: time,
          ),
          header: [_Name(person), _PersonMeta(person)],
          body: [
            if (time != null && servedByName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l.servedAtBy(time, isolate(servedByName)),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.clayInk,
                  ),
                ),
              ),
            Text(
              time == null ? l.alreadyServedNoteNoTime : l.alreadyServedNote(time),
              style: TextStyle(fontSize: 13, color: c.clayInk),
            ),
          ],
          footer: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.sky,
                foregroundColor: AppPalette.onSky,
              ),
              onPressed: controller.scanNext,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: Text(l.scanNextCard),
            ),
            _Links([
              (l.history, () => showMealHistory(context, person)),
              (l.details, () => context.push('/people/${person.id}')),
            ]),
          ],
        );

      case ScanNotFound(:final personId):
        final region = ref.read(authControllerProvider).value?.region?.name ?? '';
        return _Sheet(
          band: _Band(
            color: c.systemBand,
            seal: problem,
            title: l.unknownCardTitle(personId),
            subtitle: l.unknownCardMessage(region),
            small: true,
          ),
          body: [
            FilledButton.icon(
              onPressed: () => _openOver(context, controller, '/register-card?id=$personId'),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(l.registerThisCard),
            ),
            _Links([(l.scanAgain, controller.scanNext)]),
          ],
        );

      case ScanInvalidCode():
        return _Sheet(
          band: _Band(
            color: c.systemBand,
            seal: problem,
            title: l.invalidCodeTitle,
            subtitle: l.invalidCodeMessage,
            small: true,
          ),
          body: [
            OutlinedButton.icon(
              onPressed: onFindWithoutCard,
              icon: const Icon(Icons.search_rounded),
              label: Text(l.findNoCard),
            ),
            _Links([(l.scanAgain, controller.scanNext)]),
          ],
        );

      case ScanFailed(:final failure, :final person, :final duringConfirm, :final noCard):
        if (duringConfirm) {
          return _Sheet(
            band: _Band(
              color: c.systemBand,
              seal: problem,
              title: l.notConfirmedYet,
              subtitle: l.dontHandOverYet,
              small: true,
            ),
            header: [
              if (person != null) ...[
                _Name(person),
                _PersonMeta(person),
                if (noCard) _NoCardCheck(person),
              ],
            ],
            body: [
              Text(
                '${failureText(l, failure)} ${l.notConfirmedExplanation}',
                style: TextStyle(fontSize: 13, color: c.ink),
              ),
            ],
            footer: [
              FilledButton.icon(
                onPressed: controller.retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.retry),
              ),
              _Links([(l.skip, controller.scanNext)]),
            ],
          );
        }
        return _Sheet(
          band: _Band(
            color: c.systemBand,
            seal: problem,
            title: failureTitle(l, failure),
            subtitle: failureText(l, failure),
            small: true,
          ),
          body: [
            FilledButton.icon(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l.retry),
            ),
            _Links([(l.cancel, controller.scanNext)]),
          ],
        );
    }
  }

  Widget _ready(
    BuildContext context,
    ScanController controller,
    FastingPerson person, {
    required String? phone,
    required String? comment,
    required bool noCard,
    required bool busy,
    bool slow = false,
  }) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return _Sheet(
      band: slow
          ? _Band(
              color: AppPalette.waitBand,
              seal: Seal(SealKind.checking, semanticLabel: l.sealChecking),
              title: l.sendingSlow,
              subtitle: l.dontHandOverYet,
              small: true,
            )
          : _Band(
              color: c.serveBand,
              seal: Seal(SealKind.serve, semanticLabel: l.sealServe),
              title: MealStatusWords.notTaken,
              subtitle: l.notServedTonight,
            ),
      // Pinned: who and the CIN check. Scrolling: quantities and contact.
      // Pinned below: the action, so Confirm never leaves the screen.
      header: [
        _Name(person),
        _PersonMeta(person),
        if (noCard) _NoCardCheck(person),
      ],
      body: [
        _Label(l.handOver),
        HandOverTiles(person: person),
        if (!busy)
          _ContactLine(
            phone: phone,
            comment: comment,
            onEdit: () async {
              final result = await showContactEditor(context, phone: phone, comment: comment);
              if (result != null) {
                controller.editContact(phone: result.phone, comment: result.comment);
              }
            },
          ),
      ],
      footer: [
        FilledButton.icon(
          onPressed: busy ? null : controller.confirm,
          icon: busy
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: c.onAct),
                )
              : const Icon(Icons.check_rounded),
          label: Text(busy ? l.confirming : l.confirmHandOver),
        ),
        _Links([
          (l.skip, busy ? null : controller.scanNext),
          (l.details, busy ? null : () => _openOver(context, controller, '/people/${person.id}')),
        ]),
      ],
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.band,
    this.header = const [],
    this.body = const [],
    this.footer = const [],
    this.background,
  });

  /// Pinned under the band: who this is.
  final Widget band;
  final List<Widget> header;

  /// Scrolls when the sheet would otherwise outgrow the screen.
  final List<Widget> body;

  /// Pinned at the bottom: the action the volunteer must always reach.
  final List<Widget> footer;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background ?? context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
      ),
      // The sheet sits over the camera. At large text sizes only the middle
      // scrolls; the band, the person and the action stay on screen.
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Pinned header and footer need roughly 250 px per unit of text
              // scale. Below that (small phone, huge text) pinning would
              // overflow, so everything under the band scrolls as one unit;
              // the verdict band always stays on screen.
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final compact = constraints.maxHeight < 300 * scale;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  band,
                  if (compact)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [...header, ...body, const SizedBox(height: 8), ...footer],
                        ),
                      ),
                    )
                  else ...[
                    if (header.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: header,
                        ),
                      ),
                    if (body.isNotEmpty)
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(18, header.isEmpty ? 14 : 4, 18, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: body,
                          ),
                        ),
                      ),
                    if (footer.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: footer,
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({
    required this.color,
    required this.seal,
    required this.title,
    this.subtitle,
    this.trailing,
    this.small = false,
  });

  final Color color;
  final Widget seal;
  final String title;
  final String? subtitle;
  final String? trailing;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 14),
        child: Row(
          children: [
            seal,
            const SizedBox(width: 12),
            Expanded(
              // Screen readers announce each new verdict (spec §8).
              child: Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: small ? 19 : 24,
                        fontWeight: small ? FontWeight.w500 : FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12.5),
                      ),
                  ],
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
    );
  }
}

class _DoneBand extends StatelessWidget {
  const _DoneBand({
    required this.person,
    required this.undoing,
    required this.undoWindow,
    required this.onUndo,
  });

  final FastingPerson person;
  final bool undoing;
  final Duration undoWindow;

  /// Null when this meal can't be undone from here.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppPalette.doneBand,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Seal(SealKind.done, semanticLabel: l.sealDone),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          blessingText,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontFamily: AppTheme.brandFont,
                            fontSize: 30,
                            height: 1.15,
                            color: AppPalette.gold,
                          ),
                        ),
                        Text(
                          l.servedLine(isolate(person.fullName), person.totalPortions),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        ),
                        if (l.blessingMeaning.isNotEmpty)
                          Text(
                            l.blessingMeaning,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5),
                          ),
                        if (onUndo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _UndoButton(
                              window: undoWindow,
                              undoing: undoing,
                              onPressed: onUndo!,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Undo · 5", counting down while the band is shown (spec 2A §5.2).
class _UndoButton extends StatefulWidget {
  const _UndoButton({
    required this.window,
    required this.undoing,
    required this.onPressed,
  });

  final Duration window;
  final bool undoing;
  final VoidCallback onPressed;

  @override
  State<_UndoButton> createState() => _UndoButtonState();
}

class _UndoButtonState extends State<_UndoButton> {
  late int _left = widget.window.inSeconds.clamp(1, 60);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_left > 1) setState(() => _left--);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
        minimumSize: const Size(0, 44),
      ),
      onPressed: widget.undoing ? null : widget.onPressed,
      icon: widget.undoing
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.undo_rounded),
      label: Text(l.undoCountdown(_left)),
    );
  }
}

class _Name extends StatelessWidget {
  const _Name(this.person);

  final FastingPerson person;

  @override
  Widget build(BuildContext context) => Text(
    person.fullName,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
  );
}

class _PersonMeta extends StatelessWidget {
  const _PersonMeta(this.person);

  final FastingPerson person;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final masked = maskCin(person.cin);
    return Text(
      [
        ltr('#${person.id}'),
        if (masked != null) '${l.cinShortLabel} ${ltr(masked)}',
      ].join(' · '),
      style: TextStyle(fontSize: 12.5, color: context.colors.inkMuted),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(text, style: TextStyle(fontSize: 12, color: context.colors.inkMuted)),
  );
}

class _NoCardCheck extends StatelessWidget {
  const _NoCardCheck(this.person);

  final FastingPerson person;

  @override
  Widget build(BuildContext context) {
    final digits = cinLastDigits(person.cin);
    final l = AppLocalizations.of(context);
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: c.warnSoft, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.badge_outlined, size: 16, color: c.goldInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              digits == null ? l.noCinOnFile : l.noCardCheck(ltr(digits)),
              style: TextStyle(fontSize: 12.5, color: c.goldInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.phone, required this.comment, required this.onEdit});

  final String? phone;
  final String? comment;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = [
      if (phone != null && phone!.isNotEmpty) ltr(phone!),
      if (comment != null && comment!.isNotEmpty) comment!,
    ].join(' · ');
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).editContact,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              Icon(Icons.phone_outlined, size: 15, color: c.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: c.inkMuted),
                ),
              ),
              Icon(Icons.edit_rounded, size: 15, color: c.actInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitBar extends StatelessWidget {
  const _WaitBar();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      height: 52,
      decoration: BoxDecoration(
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              AppLocalizations.of(context).checkingStatus,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: c.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens [location] on top of the scanner, which stays alive underneath with
/// its session. On return the scanner looks the person up again, so it shows
/// what Details or the registration form changed.
Future<void> _openOver(
  BuildContext context,
  ScanController controller,
  String location,
) async {
  await context.push<void>(location);
  if (context.mounted) await controller.refreshCurrent();
}

class _Links extends StatelessWidget {
  const _Links(this.links);

  final List<(String, VoidCallback?)> links;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (final (label, onTap) in links)
        Flexible(child: TextButton(onPressed: onTap, child: Text(label))),
    ],
  );
}
