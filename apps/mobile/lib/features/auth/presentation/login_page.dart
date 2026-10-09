import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/failure_text.dart';
import '../../../core/theme/iftar_colors.dart';
import '../../../core/widgets/pill_text_field.dart';
import '../../../l10n/app_localizations.dart';
import 'auth_controller.dart';
import 'auth_scaffold.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _failure = ref.read(authControllerProvider.notifier).lastSignOutFailure;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _failure = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_username.text, _password.text);
      // The router redirects to the app once signed in.
    } on AccountPendingFailure {
      if (mounted) context.go('/pending');
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
      title: l.welcomeBack,
      lead: l.loginLead,
      switchLabel: l.newVolunteerCreateAccount,
      onSwitch: () => context.pushReplacement('/register'),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillTextField(
                controller: _username,
                hint: l.username,
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l.usernameRequired : null,
              ),
              PillTextField(
                controller: _password,
                hint: l.password,
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                suffix: IconButton(
                  tooltip: _obscure ? l.showPassword : l.hidePassword,
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: context.colors.inkMuted,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                validator: (v) => (v == null || v.isEmpty) ? l.passwordRequired : null,
              ),
              if (_failure != null) FormErrorBanner(failureText(l, _failure!)),
              const SizedBox(height: 16),
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
                    : Text(l.signIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
