import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Rounded "pill" input with a soft drop shadow — the Ionic auth-screen style
/// (radius 50, ~45-48 px tall, `box-shadow: 1px 8px 8px rgba(0,0,0,.08)`).
class PillTextField extends StatelessWidget {
  const PillTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.suffix,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final FormFieldValidator<String>? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      borderSide: BorderSide.none,
    );
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
        child: TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onFieldSubmitted: onSubmitted,
          enabled: enabled,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null
                ? null
                : Icon(icon, color: AppColors.inkMuted, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: 15,
            ),
            border: pill,
            enabledBorder: pill,
            focusedBorder: pill.copyWith(
              borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
            ),
            errorBorder: pill.copyWith(
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: pill.copyWith(
              borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
            ),
            errorStyle: const TextStyle(color: AppColors.danger),
          ),
        ),
      ),
    );
  }
}
