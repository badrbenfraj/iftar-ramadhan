import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pill_text_field.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = ref.read(authControllerProvider.notifier).lastSignOutFailure?.message;
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
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_username.text, _password.text);
      // The router redirects to the app once signed in.
    } on AppFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      switchLabel: 'Sign up',
      onSwitch: () => context.pushReplacement('/register'),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillTextField(
                controller: _username,
                hint: 'Username',
                icon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Username is required.'
                    : null,
              ),
              PillTextField(
                controller: _password,
                hint: 'Password',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                suffix: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.inkMuted,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Password is required.' : null,
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
                    : const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
