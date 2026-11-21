import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_states.dart';

/// The design system's outlined text field with a floating label cut into
/// the border (TextField page), as a single-line input or a 3-row textarea.
///
/// Error state follows the page's recommended spec: 2px `color-error-500`
/// border, label and message in `color-error-500`, the message replacing
/// the helper, and a 20px error icon trailing.
class PcTextField extends StatelessWidget {
  /// Creates a text field.
  const PcTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.helper,
    this.error,
    this.placeholder,
    this.isRequired = false,
    this.enabled = true,
    this.multiline = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
  });

  /// What to enter, in the user's words ("Their full name").
  final String label;

  /// Holds the text.
  final TextEditingController? controller;

  /// Focus for keyboard flows.
  final FocusNode? focusNode;

  /// Why or the format ("The pickup OTP goes here").
  final String? helper;

  /// Error message; non-null puts the field in the error state.
  final String? error;

  /// Placeholder in `color-neutral-550`.
  final String? placeholder;

  /// Ends the label with " *".
  final bool isRequired;

  /// False shows the disabled state (38% opacity).
  final bool enabled;

  /// Textarea: 3 rows, padding 16, no resize.
  final bool multiline;

  /// Keyboard to show.
  final TextInputType? keyboardType;

  /// Keyboard action button.
  final TextInputAction? textInputAction;

  /// Input restrictions.
  final List<TextInputFormatter>? inputFormatters;

  /// Autofill hints.
  final Iterable<String>? autofillHints;

  /// Hides the text (passwords).
  final bool obscureText;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard action is pressed.
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors;
    final inputStyle = pc.text.bodyLg;
    final hasError = error != null;
    final disabledColor = colors.disabledText.withValues(
      alpha: PcOpacity.disabled,
    );

    final lineHeight = inputStyle.fontSize! * inputStyle.height!;
    final verticalPadding = multiline
        ? PcSpacing.space4
        : (pc.metrics.inputHeight - lineHeight) / 2;

    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(PcRadii.sm)),
      borderSide: BorderSide(color: color, width: width),
    );

    Color labelColor(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return disabledColor;
      if (hasError) return colors.errorTone.accent;
      if (states.contains(WidgetState.focused)) return colors.primary;
      return colors.textMuted;
    }

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: multiline ? TextInputType.multiline : keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      obscureText: obscureText,
      minLines: multiline ? 3 : 1,
      maxLines: multiline ? 3 : 1,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      cursorColor: hasError ? colors.errorTone.accent : colors.primary,
      style: inputStyle.copyWith(
        color: enabled ? colors.text : disabledColor,
      ),
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        labelStyle: WidgetStateTextStyle.resolveWith(
          (states) => inputStyle.copyWith(color: labelColor(states)),
        ),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => pc.text.fieldLabel.copyWith(color: labelColor(states)),
        ),
        hintText: placeholder,
        hintStyle: inputStyle.copyWith(color: colors.placeholder),
        helperText: helper,
        helperStyle: pc.text.helper.copyWith(color: colors.textMuted),
        helperMaxLines: 2,
        errorText: error,
        errorStyle: pc.text.helper.copyWith(color: colors.errorTone.accent),
        errorMaxLines: 2,
        suffixIcon: hasError
            ? Icon(
                Icons.error_outline,
                size: PcSizes.iconMd,
                color: colors.errorTone.accent,
              )
            : null,
        contentPadding: EdgeInsets.symmetric(
          horizontal: PcSpacing.space4,
          vertical: verticalPadding,
        ),
        border: border(colors.outline, PcBorders.thin),
        enabledBorder: border(colors.outline, PcBorders.thin),
        focusedBorder: border(colors.primary, PcBorders.thick),
        errorBorder: border(colors.errorTone.accent, PcBorders.thick),
        focusedErrorBorder: border(colors.errorTone.accent, PcBorders.thick),
        disabledBorder: border(disabledColor, PcBorders.thin),
      ),
    );
  }
}
