import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pill_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';
import 'auth_scaffold.dart';

final regionsProvider = FutureProvider.autoDispose<List<Region>>(
  (ref) => ref.watch(regionRepositoryProvider).listRegions(),
);

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  int? _regionId;
  bool _submitting = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    for (final c in [_name, _username, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .register(
            name: _name.text,
            username: _username.text,
            email: _email.text,
            password: _password.text,
            regionId: _regionId!,
          );
      if (!mounted) return;
      showAppSnackBar(context, 'Account created. You can sign in now.');
      context.pushReplacement('/login');
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regions = ref.watch(regionsProvider);
    return AuthScaffold(
      title: 'Join the volunteers',
      switchLabel: 'Sign In',
      onSwitch: () => context.pushReplacement('/login'),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillTextField(
                controller: _name,
                hint: 'Name',
                icon: Icons.badge_outlined,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Name is required.'
                    : null,
              ),
              PillTextField(
                controller: _username,
                hint: 'Username',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Username is required.'
                    : null,
              ),
              _RegionPicker(
                regions: regions,
                value: _regionId,
                onChanged: (id) => setState(() => _regionId = id),
                onRetry: () => ref.invalidate(regionsProvider),
              ),
              PillTextField(
                controller: _email,
                hint: 'Email',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Email is required.';
                  if (!_emailPattern.hasMatch(value)) {
                    return 'Should be a valid email.';
                  }
                  return null;
                },
              ),
              PillTextField(
                controller: _password,
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                // Matches the backend rule (6–100 characters).
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required.';
                  if (v.length < 6) return 'Min length 6 characters.';
                  return null;
                },
              ),
              if (_error != null) FormErrorBanner(_error!),
              const SizedBox(height: AppSpacing.lg),
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
                    : const Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionPicker extends StatelessWidget {
  const _RegionPicker({
    required this.regions,
    required this.value,
    required this.onChanged,
    required this.onRetry,
  });

  final AsyncValue<List<Region>> regions;
  final int? value;
  final ValueChanged<int?> onChanged;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      borderSide: BorderSide.none,
    );
    final items = regions.value ?? const <Region>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              offset: Offset(1, 8),
              blurRadius: 8,
            ),
          ],
        ),
        child: DropdownButtonFormField<int>(
          initialValue: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(AppRadii.field),
          hint: Text(
            regions.isLoading
                ? 'Loading regions…'
                : regions.hasError
                ? 'Could not load regions'
                : 'Choose region',
          ),
          items: [
            for (final r in items)
              DropdownMenuItem(value: r.id, child: Text(r.name)),
          ],
          onChanged: items.isEmpty ? null : onChanged,
          validator: (v) => v == null ? 'Region is required.' : null,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              color: AppColors.inkMuted,
              size: 20,
            ),
            suffixIcon: regions.hasError
                ? IconButton(
                    tooltip: 'Retry',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: onRetry,
                  )
                : null,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: 15,
            ),
            border: pill,
            enabledBorder: pill,
            focusedBorder: pill,
            errorBorder: pill.copyWith(
              borderSide: const BorderSide(color: AppColors.danger),
            ),
          ),
        ),
      ),
    );
  }
}
