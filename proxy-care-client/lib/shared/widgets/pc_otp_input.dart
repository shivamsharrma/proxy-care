import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';

/// Six equal cells for a one-time code (OtpInput page).
///
/// A single hidden text field takes the input, so paste, SMS autofill
/// (`one-time-code`) and the numeric keyboard all work; the cells only
/// display it. Each cell is labelled "Digit n of 6" for screen readers.
///
/// The countdown and "Resend SMS" buttons under the cells are composed by
/// the screen from `PcButton`s.
class PcOtpInput extends StatefulWidget {
  /// Creates an OTP input.
  const PcOtpInput({
    super.key,
    this.controller,
    this.focusNode,
    this.error,
    this.onChanged,
    this.onCompleted,
    this.autofocus = false,
    this.semanticLabel,
    this.cellLabel,
  });

  /// Number of cells.
  static const int length = 6;

  /// Holds the digits.
  final TextEditingController? controller;

  /// Focus for keyboard flows.
  final FocusNode? focusNode;

  /// Error message shown under the cells; non-null outlines every cell in
  /// `color-error-500`.
  final String? error;

  /// Called on every change.
  final ValueChanged<String>? onChanged;

  /// Called once all six digits are entered.
  final ValueChanged<String>? onCompleted;

  /// Whether the field takes focus when first shown.
  final bool autofocus;

  /// Label of the whole field. Defaults to the localized "One-time code".
  final String? semanticLabel;

  /// Builds each cell's label from its 1-based position and the length.
  /// Defaults to the localized "Digit n of 6".
  final String Function(int position, int length)? cellLabel;

  @override
  State<PcOtpInput> createState() => _PcOtpInputState();
}

class _PcOtpInputState extends State<PcOtpInput> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_rebuild);
    _focusNode.addListener(_rebuild);
  }

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _focusNode.removeListener(_rebuild);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _handleChanged(String value) {
    widget.onChanged?.call(value);
    if (value.length == PcOtpInput.length) widget.onCompleted?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    final l10n = AppLocalizations.of(context);
    final cellLabel = widget.cellLabel ?? l10n.a11yOtpDigit;
    final text = _controller.text;
    final hasError = widget.error != null;
    final activeIndex = _focusNode.hasFocus
        ? (text.length < PcOtpInput.length
              ? text.length
              : PcOtpInput.length - 1)
        : -1;

    final cells = <Widget>[
      for (var i = 0; i < PcOtpInput.length; i++) ...[
        if (i > 0) const SizedBox(width: PcSpacing.space2),
        Expanded(
          child: Semantics(
            label: cellLabel(i + 1, PcOtpInput.length),
            value: i < text.length ? text[i] : '',
            child: Container(
              height: PcSizes.otpCell,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: const BorderRadius.all(
                  Radius.circular(PcRadii.lg),
                ),
                border: Border.all(
                  color: hasError
                      ? colors.errorTone.accent
                      : i == activeIndex
                      ? colors.primary
                      : colors.outlineVariant,
                  width: hasError || i == activeIndex
                      ? PcBorders.thick
                      : PcBorders.thin,
                ),
              ),
              child: ExcludeSemantics(
                child: Text(
                  i < text.length ? text[i] : '',
                  style: PcTypeScale.otpDigit.copyWith(color: colors.text),
                ),
              ),
            ),
          ),
        ),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                label: widget.semanticLabel ?? l10n.a11yOtpField,
                textField: true,
                child: Opacity(
                  opacity: 0,
                  alwaysIncludeSemantics: true,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(PcOtpInput.length),
                    ],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    onChanged: _handleChanged,
                  ),
                ),
              ),
            ),
            IgnorePointer(child: Row(children: cells)),
          ],
        ),
        if (hasError) ...[
          const SizedBox(height: PcSpacing.space2),
          Text(
            widget.error!,
            style: PcTypeScale.bodyMd.copyWith(
              color: colors.errorTone.accent,
            ),
          ),
        ],
      ],
    );
  }
}
