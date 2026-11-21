import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_states.dart';
import 'pc_focus_ring.dart';

/// The design system's 52×32 on/off switch (Switch page, decision #9).
///
/// On: `color-primary-500` track, 24px white thumb at the end with a 16px
/// check. Off: `color-neutral-150` track with a 2px `color-outline` border
/// and a 16px `color-outline` thumb at the start. Place it at the end of a
/// labelled row and pass the row title as [semanticLabel].
class PcSwitch extends StatelessWidget {
  /// Creates a switch.
  const PcSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value. Null disables the switch (38% opacity).
  final ValueChanged<bool>? onChanged;

  /// The row title, announced with the switch state.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    final enabled = onChanged != null;
    final thumbSize = value ? PcSizes.switchThumbOn : PcSizes.switchThumbOff;

    final track = Container(
      width: PcSizes.switchWidth,
      height: PcSizes.switchHeight,
      // The 4px inner padding is measured inside the 2px "off" border.
      padding: EdgeInsets.all(
        value ? PcSizes.switchPadding : PcSizes.switchPadding + PcBorders.thick,
      ),
      alignment: value
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      decoration: ShapeDecoration(
        color: value ? colors.primary : colors.surfaceContainerHigh,
        shape: StadiumBorder(
          side: value
              ? BorderSide.none
              : BorderSide(color: colors.outline, width: PcBorders.thick),
        ),
      ),
      child: Container(
        width: thumbSize,
        height: thumbSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: value ? colors.onPrimary : colors.outline,
          shape: BoxShape.circle,
        ),
        child: value
            ? Icon(
                Icons.check,
                size: PcSizes.switchCheck,
                color: colors.primary,
              )
            : null,
      ),
    );

    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? () => onChanged!(!value) : null,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : PcOpacity.disabled,
        child: PcFocusRing(
          borderRadius: PcSizes.switchHeight / 2,
          child: FocusableActionDetector(
            enabled: enabled,
            mouseCursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) => onChanged?.call(!value),
              ),
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => onChanged!(!value) : null,
              child: track,
            ),
          ),
        ),
      ),
    );
  }
}
