import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/meal_stepper.dart';
import '../../../core/widgets/night_sky.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../scan/presentation/card_id_scanner.dart';
import '../data/people_repository.dart';
import '../domain/fasting_person.dart';
import '../domain/person_draft.dart';
import '../domain/person_lookup.dart';
import 'people_controller.dart';

/// Digits typed on an Arabic keyboard (٠–٩) become 0–9 before the digit
/// filter would otherwise drop them.
final _digitsOnly = <TextInputFormatter>[
  TextInputFormatter.withFunction((oldValue, newValue) {
    final text = latinDigits(newValue.text);
    return text == newValue.text ? newValue : newValue.copyWith(text: text);
  }),
  FilteringTextInputFormatter.digitsOnly,
];

/// Add tab (spec §4.5).
class AddPersonPage extends StatelessWidget {
  const AddPersonPage({
    super.key,
    this.initialId,
    this.scanCardId,
    this.overScanner = false,
  });

  final int? initialId;
  final CardIdScanner? scanCardId;

  /// Opened over the scanner ("Register this card"): shows a way back, and
  /// saving returns to the scanner instead of the people list.
  final bool overScanner;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkyBand(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (overScanner)
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: BackButton(),
                  )
                else
                  const SizedBox(height: 4),
                Text(l.addTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                Text(l.addSubtitle, style: const TextStyle(fontSize: 13, color: AppPalette.onSkyMuted)),
              ],
            ),
          ),
          Expanded(
            child: PersonForm(
              key: ValueKey(initialId),
              initialId: initialId,
              scanCardId: scanCardId,
              backToScanner: overScanner,
            ),
          ),
        ],
      ),
    );
  }
}

/// Edit screen.
class EditPersonPage extends ConsumerWidget {
  const EditPersonPage({super.key, required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personDetailsProvider(personId));
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).editTitle)),
      body: switch (person) {
        AsyncData(:final value) => PersonForm(person: value),
        AsyncError(:final error) => ErrorView(
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(personDetailsProvider(personId)),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class PersonForm extends ConsumerStatefulWidget {
  const PersonForm({
    super.key,
    this.person,
    this.initialId,
    this.scanCardId,
    this.backToScanner = false,
  });

  /// Null when creating.
  final FastingPerson? person;
  final int? initialId;

  /// Saving pops back to the scanner underneath instead of going to the list.
  final bool backToScanner;

  /// Injectable for tests; defaults to the camera sheet.
  final CardIdScanner? scanCardId;

  bool get isEdit => person != null;

  @override
  ConsumerState<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends ConsumerState<PersonForm> {
  final _formKey = GlobalKey<FormState>();
  final _idKey = GlobalKey<FormFieldState<String>>();
  final _idFocus = FocusNode();
  late final _id = TextEditingController(
    text: '${widget.person?.id ?? widget.initialId ?? ''}',
  );
  late final _cin = TextEditingController(text: widget.person?.cin ?? '');
  late final _firstName = TextEditingController(text: widget.person?.firstName ?? '');
  late final _lastName = TextEditingController(text: widget.person?.lastName ?? '');
  late final _phone = TextEditingController(text: widget.person?.phone ?? '');
  late final _comment = TextEditingController(text: widget.person?.comment ?? '');
  late int _single = widget.person?.singleMeal ?? 1;
  late int _family = widget.person?.familyMeal ?? 0;
  late bool _showOptional =
      widget.person?.phone != null || widget.person?.comment != null;
  bool _cameToday = true;
  bool _submitting = false;
  bool _mealsInvalid = false;
  String? _idServerError;

  List<TextEditingController> get _controllers =>
      [_id, _cin, _firstName, _lastName, _phone, _comment];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _idFocus.dispose();
    super.dispose();
  }

  Future<void> _scanId() async {
    final scanner = widget.scanCardId ?? showCardIdScanner;
    final id = await scanner(context);
    if (id == null || !mounted) return;
    setState(() {
      _id.text = '$id';
      _idServerError = null;
    });
    // Drop a stale "already registered" message for the previous ID.
    _idKey.currentState?.validate();
    showAppSnackBar(context, AppLocalizations.of(context).cardRead(ltr('$id')));
  }

  void _resetForNext() {
    _formKey.currentState!.reset();
    for (final c in _controllers) {
      c.clear();
    }
    setState(() {
      _single = 1;
      _family = 0;
      _cameToday = true;
      _showOptional = false;
      _mealsInvalid = false;
    });
    _idFocus.requestFocus();
  }

  Future<void> _submit({bool addAnother = false}) async {
    FocusScope.of(context).unfocus();
    final l = AppLocalizations.of(context);
    final meals = PersonRules.normalizeMeals('$_single', '$_family');
    setState(() {
      _mealsInvalid = meals == null;
      _idServerError = null;
    });
    final valid = _formKey.currentState!.validate();
    if (!valid || meals == null) return;

    final draft = PersonDraft(
      id: int.parse(latinDigits(_id.text).trim()),
      firstName: _firstName.text,
      lastName: _lastName.text,
      cin: latinDigits(_cin.text),
      phone: _phone.text,
      comment: _comment.text,
      singleMeal: meals.single,
      familyMeal: meals.family,
      cameToday: _cameToday,
    );

    setState(() => _submitting = true);
    try {
      final region = regionOf(ref.read(authControllerProvider));
      final repo = ref.read(peopleRepositoryProvider);
      final saved = widget.isEdit
          ? await repo.update(region, draft)
          : await repo.create(region.id, draft);
      ref.read(peopleListProvider.notifier).upsert(saved);
      if (widget.isEdit) ref.invalidate(personDetailsProvider(saved.id));
      if (!mounted) return;
      final name = isolate(saved.fullName);
      showAppSnackBar(
        context,
        widget.isEdit
            ? l.personUpdated
            : draft.cameToday
            ? l.personSavedHandOver(name, saved.totalPortions)
            : l.personSaved(name),
      );
      if (widget.isEdit) {
        context.pop();
      } else {
        _resetForNext();
        if (!addAnother) {
          if (widget.backToScanner && context.canPop()) {
            context.pop();
          } else {
            context.go('/people');
          }
        }
      }
    } on MealAlreadyTakenFailure catch (e) {
      if (mounted) showAppSnackBar(context, failureText(l, e), isError: true);
    } on ConflictFailure {
      setState(() => _idServerError = l.idTaken);
      _formKey.currentState!.validate();
    } on AppFailure catch (e) {
      if (mounted) showAppSnackBar(context, failureText(l, e), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final person = widget.person!;
    final c = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteTitle),
        content: Text(l.deleteBody(isolate(person.fullName))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: c.clay,
              foregroundColor: c.onClay,
              minimumSize: const Size(96, 48),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      final region = regionOf(ref.read(authControllerProvider));
      await ref.read(peopleRepositoryProvider).delete(region.id, person.id);
      ref.read(peopleListProvider.notifier).remove(person.id);
      if (!mounted) return;
      showAppSnackBar(context, l.personDeleted(isolate(person.fullName)));
      context.go('/people');
    } on AppFailure catch (e) {
      if (mounted) showAppSnackBar(context, failureText(l, e), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    const target = Size(48, 48);

    Widget labeled(String label, Widget field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
          child: ExcludeSemantics(
            child: Text(label, style: TextStyle(fontSize: 12.5, color: c.inkMuted)),
          ),
        ),
        Semantics(label: label, child: field),
      ],
    );

    return Form(
      key: _formKey,
      child: ListView(
        // Clears the shell's 72 px bar (the Add tab sits under it) and the
        // system inset, with air above the save buttons.
        padding: EdgeInsetsDirectional.fromSTEB(
          20,
          16,
          20,
          72 + MediaQuery.viewPaddingOf(context).bottom + 40,
        ),
        children: [
          labeled(
            l.cardId,
            TextFormField(
              key: _idKey,
              controller: _id,
              focusNode: _idFocus,
              enabled: !widget.isEdit,
              keyboardType: TextInputType.number,
              inputFormatters: _digitsOnly,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                suffixIcon: widget.isEdit
                    ? null
                    : Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(minimumSize: target),
                          onPressed: _scanId,
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                          label: Text(l.scanCard),
                        ),
                      ),
              ),
              validator: (v) {
                if (_idServerError != null) return _idServerError;
                final value = latinDigits(v ?? '');
                if (PersonRules.validateId(value) == null) return null;
                return value.trim().isEmpty ? l.idRequired : l.idInvalid;
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: labeled(
                  l.firstName,
                  TextFormField(
                    controller: _firstName,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l.firstNameRequired : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: labeled(
                  l.lastName,
                  TextFormField(
                    controller: _lastName,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? l.lastNameRequired : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          labeled(
            l.cinLabel,
            TextFormField(
              controller: _cin,
              keyboardType: TextInputType.number,
              inputFormatters: [
                ..._digitsOnly,
                LengthLimitingTextInputFormatter(PersonRules.cinLength),
              ],
              textDirection: TextDirection.ltr,
              validator: (v) =>
                  PersonRules.validateCin(latinDigits(v ?? '')) == null ? null : l.cinLength,
            ),
          ),
          _DuplicateCinWarning(controller: _cin, excludeId: widget.person?.id),
          const SizedBox(height: 18),
          labeled(
            l.mealsEachEvening,
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    MealStepper(
                      label: l.singleMeal,
                      caption: l.portions(1),
                      value: _single,
                      onChanged: (v) => setState(() {
                        _single = v;
                        _mealsInvalid = false;
                      }),
                    ),
                    const Divider(),
                    MealStepper(
                      label: l.familyMeal,
                      caption: l.portions(4),
                      value: _family,
                      onChanged: (v) => setState(() {
                        _family = v;
                        _mealsInvalid = false;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, top: 8),
            child: Text(
              l.handsOverEachEvening(_single + _family * 4),
              style: TextStyle(fontSize: 12.5, color: c.goldInk),
            ),
          ),
          if (_mealsInvalid)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 2, top: 6),
              child: Text(l.mealsAtLeastOne, style: TextStyle(color: c.clay)),
            ),
          if (!widget.isEdit) ...[
            const SizedBox(height: 14),
            Card(
              child: SwitchListTile(
                value: _cameToday,
                onChanged: (v) => setState(() => _cameToday = v),
                title: Text(l.hereNow),
                subtitle: Text(l.hereNowSubtitle),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _showOptional = !_showOptional),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l.optionalFields, style: TextStyle(color: c.actInk, fontSize: 14)),
                    ),
                    Icon(
                      _showOptional ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: c.actInk,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showOptional) ...[
            labeled(
              l.phone,
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
              ),
            ),
            const SizedBox(height: 12),
            labeled(
              l.notes,
              TextFormField(controller: _comment, minLines: 1, maxLines: 3),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: c.onAct),
                  )
                : Text(
                    widget.isEdit
                        ? l.updatePerson
                        : _cameToday
                        ? l.saveAndHandOver
                        : l.save,
                  ),
          ),
          if (!widget.isEdit)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: _submitting ? null : () => _submit(addAnother: true),
              child: Text(l.saveAndAddAnother),
            ),
          if (widget.isEdit) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: c.clay,
                side: BorderSide(color: c.clay),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _submitting ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(l.deletePerson),
            ),
          ],
        ],
      ),
    );
  }
}

/// Advisory duplicate check against the cached region list (spec §4.5).
class _DuplicateCinWarning extends ConsumerWidget {
  const _DuplicateCinWarning({required this.controller, this.excludeId});

  final TextEditingController controller;
  final int? excludeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleListProvider).value ?? const <FastingPerson>[];
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final duplicate = findByCin(
          people,
          latinDigits(controller.text),
          excludeId: excludeId,
        );
        if (duplicate == null) return const SizedBox.shrink();
        final l = AppLocalizations.of(context);
        final c = context.colors;
        return Semantics(
          liveRegion: true,
          container: true,
          child: Container(
            margin: const EdgeInsetsDirectional.only(top: 8),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 4),
            decoration: BoxDecoration(
              color: c.claySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 1, end: 8),
                      child: Icon(Icons.warning_amber_rounded, size: 18, color: c.clayInk),
                    ),
                    Expanded(
                      child: Text(
                        l.duplicateCin(isolate(duplicate.fullName), ltr('${duplicate.id}')),
                        style: TextStyle(color: c.clayInk, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: c.clayInk,
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () => context.push('/people/${duplicate.id}'),
                  child: Text(l.openExistingRecord),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
