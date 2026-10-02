import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/info_tile.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/fasting_person.dart';
import 'people_controller.dart';
import 'person_widgets.dart';

class PersonDetailsPage extends ConsumerStatefulWidget {
  const PersonDetailsPage({super.key, required this.personId});

  final int personId;

  @override
  ConsumerState<PersonDetailsPage> createState() => _PersonDetailsPageState();
}

class _PersonDetailsPageState extends ConsumerState<PersonDetailsPage> {
  // Phone/comment edits made before confirming (sent with the confirmation).
  String? _phone;
  String? _comment;
  bool _confirming = false;

  Future<void> _editContact(FastingPerson person) async {
    final result = await showContactEditor(
      context,
      phone: _phone ?? person.phone,
      comment: _comment ?? person.comment,
    );
    if (result != null) {
      setState(() {
        _phone = result.phone;
        _comment = result.comment;
      });
    }
  }

  Future<void> _confirm() async {
    final l = AppLocalizations.of(context);
    setState(() => _confirming = true);
    try {
      await ref
          .read(personDetailsProvider(widget.personId).notifier)
          .confirmMeal(phone: _phone, comment: _comment);
      await HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() => _phone = _comment = null);
        showAppSnackBar(context, l.mealConfirmed);
      }
    } on MealAlreadyTakenFailure catch (e) {
      await HapticFeedback.heavyImpact();
      if (mounted) {
        showAppSnackBar(
          context,
          e.takenAt == null
              ? l.alreadyCollected
              : l.alreadyCollectedAt(ltr(formatTime(e.takenAt!))),
          isError: true,
        );
      }
    } on AppFailure catch (e) {
      if (mounted) showAppSnackBar(context, failureText(l, e), isError: true);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = personDetailsProvider(widget.personId);
    final person = ref.watch(provider);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.detailsTitle),
        actions: [
          if (person.hasValue)
            TextButton.icon(
              onPressed: () => context.push('/people/${widget.personId}/edit'),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.edit),
            ),
        ],
      ),
      body: switch (person) {
        AsyncData(:final value) => _body(value),
        AsyncError(:final error) => ErrorView(
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(provider),
        ),
        _ => const LoadingView(),
      },
    );
  }

  Widget _body(FastingPerson person) {
    final l = AppLocalizations.of(context);
    final taken = person.isMealTakenToday();
    final phone = _phone ?? person.phone;
    final comment = _comment ?? person.comment;
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(personDetailsProvider(widget.personId).notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          InfoCard(
            title: l.identity,
            children: [
              InfoTile(label: l.identifier, value: ltr('${person.id}')),
              if (person.cin != null)
                InfoTile(
                  label: l.cinShortLabel,
                  value: ltr(person.cin!),
                ),
              InfoTile(label: l.firstName, value: isolate(person.firstName)),
              InfoTile(label: l.lastName, value: isolate(person.lastName)),
              InfoTile(
                label: l.phone,
                value: phone == null || phone.isEmpty ? null : ltr(phone),
                trailing: taken ? null : _editIcon(l, person),
              ),
              InfoTile(
                label: l.comment,
                value: comment,
                trailing: taken ? null : _editIcon(l, person),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          InfoCard(
            title: l.meals,
            children: [
              InfoTile(label: l.singleMeal, value: ltr('${person.singleMeal}')),
              InfoTile(label: l.familyMeal, value: ltr('${person.familyMeal}')),
              InfoTile(
                label: l.mealToday,
                trailing: StatusChip(person: person),
                value: person.lastTakenMeal == null
                    ? null
                    : l.lastMeal(formatDate(person.lastTakenMeal!)),
                onTap: () => showMealHistory(context, person),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton.icon(
            onPressed: taken || _confirming ? null : _confirm,
            icon: _confirming
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: context.colors.onAct,
                    ),
                  )
                : Icon(taken ? Icons.check_rounded : Icons.restaurant_rounded),
            label: Text(taken ? l.alreadyServedToday : l.confirmMeal),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: () => showMealHistory(context, person),
            icon: const Icon(Icons.history_rounded),
            label: Text(l.mealHistory(person.takenMeals.length)),
          ),
        ],
      ),
    );
  }

  Widget _editIcon(AppLocalizations l, FastingPerson person) => IconButton(
    tooltip: l.editContact,
    visualDensity: VisualDensity.compact,
    icon: Icon(Icons.edit_rounded, size: 18, color: context.colors.actInk),
    onPressed: () => _editContact(person),
  );
}
