import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mani/core/theme/app_theme.dart';

/// Widget de campo de texto reutilizable con estilo MANI.
///
/// Es el campo obligatorio en pantallas nuevas o modificadas (SCRUM-1648).
/// `decoration` permite conservar una decoración propia de la pantalla;
/// `label`, `hint` y `helperText`, si se pasan, se aplican encima de ella.
class ManiTextField extends StatelessWidget {
  const ManiTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.autofillHints,
    this.initialValue,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.style,
    this.decoration,
    this.focusNode,
    this.minLines,
    this.textCapitalization = TextCapitalization.none,
    this.buildCounter,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final Iterable<String>? autofillHints;
  final String? initialValue;
  final bool enabled;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextStyle? style;
  final InputDecoration? decoration;
  final FocusNode? focusNode;
  final int? minLines;
  final TextCapitalization textCapitalization;
  final InputCounterWidgetBuilder? buildCounter;

  @override
  Widget build(BuildContext context) {
    final base =
        decoration ??
        InputDecoration(
          prefixIcon: prefixIcon != null
              ? IconTheme(
                  data: IconThemeData(color: context.mani.inkMuted, size: 20),
                  child: prefixIcon!,
                )
              : null,
          suffixIcon: suffixIcon,
        );
    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      autofillHints: autofillHints,
      validator: validator,
      maxLines: maxLines,
      minLines: minLines,
      focusNode: focusNode,
      textCapitalization: textCapitalization,
      buildCounter: buildCounter,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style:
          style ??
          TextStyle(color: context.mani.ink, fontSize: ManiFontSize.bodyLg),
      decoration: base.copyWith(
        labelText: label ?? base.labelText,
        hintText: hint ?? base.hintText,
        helperText: helperText ?? base.helperText,
      ),
    );
  }
}
