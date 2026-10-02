import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/masking.dart';
import '../../../core/widgets/night_sky.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../../people/domain/fasting_person.dart';
import '../../people/presentation/people_controller.dart';

/// "Without a card" (spec §4.7). Searches the phone's list, so it works
/// offline; pops with the chosen person ID. Shows the masked CIN only
/// (spec §4.6).
class FindPersonPage extends ConsumerStatefulWidget {
  const FindPersonPage({super.key});

  @override
  ConsumerState<FindPersonPage> createState() => _FindPersonPageState();
}

class _FindPersonPageState extends ConsumerState<FindPersonPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final people =
        ref.watch(peopleListProvider).value ?? const <FastingPerson>[];
    final now = ref.watch(clockProvider)();
    final q = latinDigits(_query.text).trim();
    final digits = RegExp(r'^\d+$').hasMatch(q);
    final ready = q.length >= 2 || digits;
    final results = ready
        ? [
            for (final p in people)
              if (p.matches(q)) p,
          ]
        : const <FastingPerson>[];
    final typedId = digits ? int.tryParse(q) : null;
    final offerLookUp =
        typedId != null && typedId > 0 && !results.any((p) => p.id == typedId);

    return Scaffold(
      body: Column(
        children: [
          SkyBand(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: l.back,
                      color: AppPalette.onSky,
                      icon: const BackButtonIcon(),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        l.findTitle,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l.findSearchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.field),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: !ready
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      l.findMinChars,
                      style: TextStyle(color: c.inkMuted),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      if (offerLookUp)
                        Card(
                          child: ListTile(
                            minTileHeight: 56,
                            leading: Icon(Icons.badge_outlined, color: c.actInk),
                            title: Text(l.findLookUpId(typedId)),
                            onTap: () => context.pop(typedId),
                          ),
                        ),
                      for (final p in results) ...[
                        _ResultRow(
                          person: p,
                          now: now,
                          onTap: () => context.pop(p.id),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (results.isEmpty && !offerLookUp)
                        EmptyView(
                          icon: Icons.search_off_rounded,
                          title: l.noMatch(isolate(q)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.person,
    required this.now,
    required this.onTap,
  });

  final FastingPerson person;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppLocalizations.of(context);
    final masked = maskCin(person.cin);
    final status = person.isMealTakenToday(now)
        ? l.servedTooltip
        : l.notServedTooltip;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${person.fullName}, $status',
      onTap: onTap,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    constraints: const BoxConstraints(minWidth: 50),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: c.chip,
                      borderRadius: BorderRadius.circular(AppRadii.chip),
                    ),
                    child: Text(
                      ltr(person.id.toString().padLeft(4, '0')),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: c.chipInk,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isolate(person.fullName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusChip(person: person, now: now),
                            if (masked != null)
                              Text(
                                '${l.cinShortLabel} ${ltr(masked)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: c.inkMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
