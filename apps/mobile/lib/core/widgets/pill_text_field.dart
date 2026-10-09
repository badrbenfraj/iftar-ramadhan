import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/iftar_colors.dart';

/// Auth-form field: floating label, leading icon, theme border, 16 px
/// bottom gap.
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
    this.textCapitalization = TextCapitalization.none,
    this.errorText,
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
  final TextCapitalization textCapitalization;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onFieldSubmitted: onSubmitted,
        enabled: enabled,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          // A floating label, so the field keeps its accessible name
          // after the volunteer types in it.
          labelText: hint,
          prefixIcon: icon == null
              ? null
              : Icon(icon, color: context.colors.inkMuted, size: 20),
          suffixIcon: suffix,
          errorText: errorText,
        ),
      ),
    );
  }
}
