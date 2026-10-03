import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/fasting_person.dart';

/// Bottom sheet: "List of taken meals for …" (Ionic modal on the badge).
Future<void> showMealHistory(BuildContext context, FastingPerson person) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.45,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      builder: (context, scroll) {
        final l = AppLocalizations.of(context);
        if (person.takenMeals.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Text(l.noMealsYet),
            ),
          );
        }
        return ListView.separated(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          itemCount: person.takenMeals.length + 1,
          separatorBuilder: (_, i) =>
              i == 0 ? const SizedBox.shrink() : const Divider(),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  l.mealHistoryTitle(isolate(person.fullName)),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              );
            }
            final date = person.takenMeals[i - 1];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.nightlight_round,
                color: context.colors.goldInk,
              ),
              title: Text(formatDate(date)),
              trailing: Text(
                ltr(formatTime(date)),
                style: TextStyle(color: context.colors.inkMuted),
              ),
            );
          },
        );
      },
    ),
  );
}

/// Edits phone and comment, which can change while confirming a meal.
Future<({String phone, String comment})?> showContactEditor(
  BuildContext context, {
  String? phone,
  String? comment,
}) {
  final phoneCtrl = TextEditingController(text: phone ?? '');
  final commentCtrl = TextEditingController(text: comment ?? '');
  return showDialog<({String phone, String comment})>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context);
      return AlertDialog(
        title: Text(l.contactTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: commentCtrl,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l.comment,
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(context, (
              phone: phoneCtrl.text.trim(),
              comment: commentCtrl.text.trim(),
            )),
            child: Text(l.save),
          ),
        ],
      );
    },
  ).whenComplete(() {
    phoneCtrl.dispose();
    commentCtrl.dispose();
  });
}
