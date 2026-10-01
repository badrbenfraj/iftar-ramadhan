import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/people_repository.dart';
import '../domain/fasting_person.dart';
import '../domain/person_draft.dart';
import 'people_controller.dart';

/// Add tab (Ionic tab2 "Add new person").
class AddPersonPage extends StatelessWidget {
  const AddPersonPage({super.key, this.initialId});

  final int? initialId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add new person')),
      body: PersonForm(key: ValueKey(initialId), initialId: initialId),
    );
  }
}

/// Edit screen (Ionic "Edit Person Details").
class EditPersonPage extends ConsumerWidget {
  const EditPersonPage({super.key, required this.personId});

  final int personId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(personDetailsProvider(personId));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Person Details')),
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
  const PersonForm({super.key, this.person, this.initialId});

  /// Null when creating.
  final FastingPerson? person;
  final int? initialId;

  bool get isEdit => person != null;

  @override
  ConsumerState<PersonForm> createState() => _PersonFormState();
}

class _PersonFormState extends ConsumerState<PersonForm> {
  final _formKey = GlobalKey<FormState>();
  late final _id = TextEditingController(
    text: '${widget.person?.id ?? widget.initialId ?? ''}',
  );
  late final _cin = TextEditingController(text: widget.person?.cin ?? '');
  late final _firstName = TextEditingController(
    text: widget.person?.firstName ?? '',
  );
  late final _lastName = TextEditingController(
    text: widget.person?.lastName ?? '',
  );
  late final _phone = TextEditingController(text: widget.person?.phone ?? '');
  late final _single = TextEditingController(
    text: widget.person == null ? '' : '${widget.person!.singleMeal}',
  );
  late final _family = TextEditingController(
    text: widget.person == null ? '' : '${widget.person!.familyMeal}',
  );
  late final _comment = TextEditingController(
    text: widget.person?.comment ?? '',
  );
  bool _cameToday = true;
  bool _submitting = false;
  bool _mealsInvalid = false;
  String? _idServerError;

  @override
  void dispose() {
    for (final c in [
      _id,
      _cin,
      _firstName,
      _lastName,
      _phone,
      _single,
      _family,
      _comment,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final meals = PersonRules.normalizeMeals(_single.text, _family.text);
    setState(() {
      _mealsInvalid = meals == null;
      _idServerError = null;
    });
    final valid = _formKey.currentState!.validate();
    if (!valid || meals == null) return;

    final draft = PersonDraft(
      id: int.parse(_id.text.trim()),
      firstName: _firstName.text,
      lastName: _lastName.text,
      cin: _cin.text,
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
      showAppSnackBar(
        context,
        widget.isEdit ? 'Person updated.' : '${isolate(saved.fullName)} added.',
      );
      if (widget.isEdit) {
        context.pop();
      } else {
        _formKey.currentState!.reset();
        for (final c in [
          _id,
          _cin,
          _firstName,
          _lastName,
          _phone,
          _single,
          _family,
          _comment,
        ]) {
          c.clear();
        }
        setState(() => _cameToday = true);
        context.go('/people');
      }
    } on ConflictFailure catch (e) {
      setState(() => _idServerError = e.message);
      _formKey.currentState!.validate();
    } on AppFailure catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete() async {
    final person = widget.person!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warning'),
        content: Text(
          'You are going to delete ${isolate(person.fullName)} from fasting persons.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size(96, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
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
      showAppSnackBar(context, '${isolate(person.fullName)} deleted.');
      context.go('/people');
    } on AppFailure catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digitsOnly = [FilteringTextInputFormatter.digitsOnly];
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          120,
        ),
        children: [
          _field(
            controller: _id,
            label: 'Identifier',
            icon: Icons.qr_code_2_rounded,
            enabled: !widget.isEdit,
            keyboardType: TextInputType.number,
            formatters: digitsOnly,
            helper: widget.isEdit ? 'The ID printed on the QR card' : null,
            validator: (v) => _idServerError ?? PersonRules.validateId(v),
          ),
          _field(
            controller: _cin,
            label: 'CIN',
            icon: Icons.credit_card_rounded,
            maxLength: PersonRules.cinLength,
            validator: PersonRules.validateCin,
          ),
          _field(
            controller: _firstName,
            label: 'First Name',
            icon: Icons.person_outline_rounded,
            validator: (v) => PersonRules.validateRequired(v, 'First name'),
          ),
          _field(
            controller: _lastName,
            label: 'Last Name',
            icon: Icons.person_outline_rounded,
            validator: (v) => PersonRules.validateRequired(v, 'Last name'),
          ),
          _field(
            controller: _phone,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  controller: _single,
                  label: 'Single meal',
                  icon: Icons.person_rounded,
                  keyboardType: TextInputType.number,
                  formatters: digitsOnly,
                  validator: PersonRules.validateMealCount,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _field(
                  controller: _family,
                  label: 'Family meal',
                  icon: Icons.family_restroom_rounded,
                  keyboardType: TextInputType.number,
                  formatters: digitsOnly,
                  validator: PersonRules.validateMealCount,
                ),
              ),
            ],
          ),
          if (_mealsInvalid)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md, left: 4),
              child: Text(
                PersonRules.mealsError,
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          _field(
            controller: _comment,
            label: 'Comments',
            icon: Icons.notes_rounded,
            maxLines: 3,
          ),
          if (!widget.isEdit)
            Card(
              child: SwitchListTile(
                value: _cameToday,
                onChanged: (v) => setState(() => _cameToday = v),
                title: const Text('Came today'),
                subtitle: const Text("Record today's meal as already taken"),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.isEdit ? 'Update person details' : 'Add new person',
                  ),
          ),
          if (widget.isEdit) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              onPressed: _submitting ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete Person'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    bool enabled = true,
    int? maxLength,
    int maxLines = 1,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        validator: validator,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: formatters,
        maxLength: maxLength,
        maxLines: maxLines,
        minLines: 1,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          counterText: '',
          prefixIcon: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
