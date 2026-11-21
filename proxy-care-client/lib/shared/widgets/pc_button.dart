import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_density.dart';
import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_colors.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';
import 'pc_focus_ring.dart';
import 'pc_state_layer.dart';

/// Button variants from the Button page.
enum PcButtonVariant {
  /// `color-primary-500` fill: the one main action on a screen.
  filled,

  /// `color-secondary-100` fill: main action inside a card.
  tonal,

  /// 1px `color-outline`: alternative action inside a card.
  outlined,

  /// No fill: secondary action under the primary, inline actions.
  text,

  /// `color-error-500` fill: confirm inside a destructive dialog only.
  destructiveFilled,

  /// No fill, `color-error-500` label: entry point to a destructive action.
  destructiveText,
}

/// Button sizes from the Button page.
enum PcButtonSize {
  /// 64: caretaker screen primary (`c-button`, icon 20).
  xl(PcSizes.buttonXl, PcTypeScale.cButton, PcSizes.iconMd),

  /// 56: family screen primary (`button`, icon 20).
  lg(PcSizes.buttonLg, PcTypeScale.button, PcSizes.iconMd),

  /// 48: dialog actions, text button under a primary (`button-sm`, icon 18).
  md(PcSizes.buttonMd, PcTypeScale.buttonSm, PcSizes.iconSm),

  /// 52: larger button inside a card (16 / 500, icon 20).
  cardLarge(PcSizes.buttonCardLg, PcTypeScale.button, PcSizes.iconMd),

  /// 44: smaller button inside a card (15 / 500, icon 18).
  cardSmall(PcSizes.buttonCardSm, PcTypeScale.listTitle, PcSizes.iconSm),

  /// 40: inline text buttons (`button-sm`, icon 18).
  sm(PcSizes.buttonSm, PcTypeScale.buttonSm, PcSizes.iconSm);

  const PcButtonSize(this.height, this.labelStyle, this.iconSize);

  /// Button height.
  final double height;

  /// Label type token.
  final TextStyle labelStyle;

  /// Icon size.
  final double iconSize;

  /// The full-width screen action size for [density]: 56 for the family
  /// app, 64 for the caretaker app.
  static PcButtonSize screenAction(AppDensity density) =>
      density == AppDensity.comfortable ? xl : lg;
}

/// The design system's pill button.
///
/// Labels are sentence case and verb first; money actions name the amount
/// and pass a lock [icon]. A disabled primary explains why with
/// [disabledReason], shown as a caption under it.
class PcButton extends StatelessWidget {
  /// Creates a button.
  const PcButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PcButtonVariant.filled,
    this.size,
    this.icon,
    this.fullWidth = false,
    this.loading = false,
    this.disabledReason,
    this.autofocus = false,
  });

  /// Visible label.
  final String label;

  /// Called on tap. Null disables the button.
  final VoidCallback? onPressed;

  /// Fill and label colors.
  final PcButtonVariant variant;

  /// Height and label style. Null uses the density's screen action size.
  final PcButtonSize? size;

  /// Optional leading icon, sized by the button.
  final Widget? icon;

  /// Stretches to the available width (bottom action area).
  final bool fullWidth;

  /// Replaces the label with a spinner while keeping the width. Taps are
  /// ignored while loading.
  final bool loading;

  /// Caption shown under a disabled button saying why it is disabled.
  final String? disabledReason;

  /// Whether the button takes focus when first shown.
  final bool autofocus;

  bool get _enabled => onPressed != null;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors;
    final resolvedSize = size ?? PcButtonSize.screenAction(pc.density);
    final palette = _palette(colors);

    final style = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? (palette.fill == null ? null : colors.disabledBg)
            : palette.fill,
      ),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return colors.disabledText;
        if (variant == PcButtonVariant.text &&
            states.contains(WidgetState.hovered)) {
          return colors.primaryHover;
        }
        return palette.label;
      }),
      overlayColor: pcStateLayer(palette.label),
      side: WidgetStateProperty.resolveWith(
        (states) =>
            variant == PcButtonVariant.outlined &&
                !states.contains(WidgetState.disabled)
            ? BorderSide(color: colors.outline, width: PcBorders.thin)
            : null,
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      minimumSize: WidgetStatePropertyAll(Size(0, resolvedSize.height)),
      maximumSize: WidgetStatePropertyAll(
        Size(double.infinity, resolvedSize.height),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsetsDirectional.only(
          start: icon == null ? PcSpacing.space6 : PcSpacing.space4,
          end: PcSpacing.space6,
        ),
      ),
      textStyle: WidgetStatePropertyAll(resolvedSize.labelStyle),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Color(0x00000000)),
      surfaceTintColor: const WidgetStatePropertyAll(Color(0x00000000)),
      splashFactory: NoSplash.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          IconTheme.merge(
            data: IconThemeData(size: resolvedSize.iconSize),
            child: icon!,
          ),
          const SizedBox(width: PcSpacing.space2),
        ],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    if (loading) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 0, child: content),
          Builder(
            builder: (context) => SizedBox.square(
              dimension: PcSizes.iconMd,
              child: CircularProgressIndicator(
                strokeWidth: PcStrokes.icon,
                color: DefaultTextStyle.of(context).style.color,
                backgroundColor: const Color(0x00000000),
              ),
            ),
          ),
        ],
      );
    }

    Widget button = PcFocusRing(
      borderRadius: resolvedSize.height / 2,
      child: TextButton(
        onPressed: loading ? (_enabled ? () {} : null) : onPressed,
        autofocus: autofocus,
        style: style,
        child: content,
      ),
    );
    if (fullWidth) button = SizedBox(width: double.infinity, child: button);

    final reason = disabledReason;
    if (_enabled || reason == null) return button;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        button,
        const SizedBox(height: PcSpacing.space2),
        Text(
          reason,
          textAlign: TextAlign.center,
          style: PcTypeScale.bodySm.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  _ButtonPalette _palette(PcColors colors) {
    return switch (variant) {
      PcButtonVariant.filled => _ButtonPalette(
        fill: colors.primary,
        label: colors.onPrimary,
      ),
      PcButtonVariant.tonal => _ButtonPalette(
        fill: colors.secondaryContainer,
        label: colors.onSecondaryContainer,
      ),
      PcButtonVariant.outlined => _ButtonPalette(
        fill: colors.surface,
        label: colors.primary,
      ),
      PcButtonVariant.text => _ButtonPalette(label: colors.primary),
      PcButtonVariant.destructiveFilled => _ButtonPalette(
        fill: colors.errorTone.accent,
        label: colors.onPrimary,
      ),
      PcButtonVariant.destructiveText => _ButtonPalette(
        label: colors.errorTone.accent,
      ),
    };
  }
}

class _ButtonPalette {
  const _ButtonPalette({required this.label, this.fill});

  final Color? fill;
  final Color label;
}
