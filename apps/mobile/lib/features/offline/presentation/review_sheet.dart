import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../people/domain/fasting_person.dart';
import '../../people/presentation/people_controller.dart';
import '../domain/offline_meal.dart';
import 'offline_queue_controller.dart';

/// "Servings to review" (spec 2B §5.3): double serves and meals the server
/// could not record. Acknowledging only clears them from this phone; the
/// server keeps them for admins.
Future<void> showReviewSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _ReviewSheet(),
);

class _ReviewSheet extends ConsumerWidget {
  const _ReviewSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final userId = ref.watch(authControllerProvider.select((a) => a.value?.id));
    final items = ref.watch(
      offlineQueueProvider.select((s) => s.reviewFor(userId)),
    );
    final people = {
      for (final p in ref.watch(peopleListProvider).value ?? const <FastingPerson>[])
        p.id: p,
    };
    final now = ref.watch(clockProvider)();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              l.reviewTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item.conflict ? Icons.people_alt_outlined : Icons.error_outline,
                color: c.clayInk,
              ),
              title: Text(
                switch (people[item.personId]) {
                  final p? => isolate(p.fullName),
                  null => ltr('#${item.personId}'),
                },
              ),
              subtitle: Text(
                [
                  l.reviewServedAt(ltr(formatSavedAt(item.servedAt, now))),
                  _reason(l, item, now),
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () async {
                  final last = items.length == 1;
                  await ref
                      .read(offlineQueueProvider.notifier)
                      .acknowledge(item.clientEventId);
                  if (last && context.mounted) Navigator.pop(context);
                },
                child: Text(l.acknowledge),
              ),
            ),
        ],
      ),
    );
  }

  static String _reason(AppLocalizations l, ReviewItem item, DateTime now) {
    if (item.conflict) {
      final at = item.otherServedAt;
      final name = item.otherServedByName;
      if (at == null) return l.reviewConflictNoName(ltr('—'));
      final time = ltr(formatSavedAt(at, now));
      return name == null
          ? l.reviewConflictNoName(time)
          : l.reviewConflict(time, isolate(name));
    }
    return switch (item.code) {
      ReviewItem.clockCode => l.reviewClock,
      ReviewItem.notFoundCode => l.reviewNotFound,
      ReviewItem.regionCode => l.reviewRegion,
      _ => l.reviewOther,
    };
  }
}
