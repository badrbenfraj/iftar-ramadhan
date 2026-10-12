import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/widgets/pill_text_field.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';
import 'auth_scaffold.dart';

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
  final _joinCode = TextEditingController();
  bool _submitting = false;
  AppFailure? _failure;
  String? _joinCodeError;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _joinCode.addListener(() => setState(() => _joinCodeError = null));
  }

  @override
  void dispose() {
    for (final c in [_name, _username, _email, _password, _joinCode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _failure = null;
      _joinCodeError = null;
    });
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .register(
            name: _name.text,
            username: _username.text,
            email: _email.text,
            password: _password.text,
            joinCode: _joinCode.text,
          );
      if (!mounted) return;
      if (result.outcome == RegisterOutcome.pending) {
        context.go('/pending', extra: result.regionName);
      } else {
        showAppSnackBar(context, AppLocalizations.of(context).accountCreated);
        context.pushReplacement('/login', extra: _username.text.trim());
      }
    } on InvalidJoinCodeFailure {
      if (mounted) {
        setState(
          () => _joinCodeError = AppLocalizations.of(context).errInvalidJoinCode,
        );
      }
    } on AppFailure catch (e) {
      if (mounted) setState(() => _failure = e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AuthScaffold(
      title: l.registerTitle,
      lead: l.registerLead,
      switchLabel: l.haveAccountSignIn,
      onSwitch: () => context.pushReplacement('/login'),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillTextField(
                controller: _name,
                hint: l.fullName,
                icon: Icons.badge_outlined,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.nameRequired : null,
              ),
              PillTextField(
                controller: _username,
                hint: l.username,
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.usernameRequired : null,
              ),
              PillTextField(
                controller: _joinCode,
                hint: l.joinCodeHint,
                icon: Icons.key_rounded,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.characters,
                errorText: _joinCodeError,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.joinCodeRequired : null,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 12),
                child: Text(
                  l.joinCodeHelp,
                  style: TextStyle(color: context.colors.inkMuted, fontSize: 12),
                ),
              ),
              PillTextField(
                controller: _email,
                hint: l.email,
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return l.emailRequired;
                  if (!_emailPattern.hasMatch(value)) return l.emailInvalid;
                  return null;
                },
              ),
              PillTextField(
                controller: _password,
                hint: l.password,
                icon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                // Matches the backend rule (8–100 characters).
                validator: (v) {
                  if (v == null || v.isEmpty) return l.passwordRequired;
                  if (v.length < 8) return l.passwordTooShort;
                  return null;
                },
              ),
              if (_failure != null) FormErrorBanner(failureText(l, _failure!)),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: context.colors.onAct,
                        ),
                      )
                    : Text(l.signUp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
