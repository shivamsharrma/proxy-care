import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_colors.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import 'pc_focus_ring.dart';
import 'pc_state_layer.dart';

/// Icon button variants from the IconButton page.
enum PcIconButtonVariant {
  /// Transparent: app bar back / close, notifications.
  standard,

  /// `color-primary-500` fill. Avoid inside cards when the screen already
  /// has a filled primary (decision #20).
  filled,

  /// `color-secondary-100` fill: call caretaker, "continue visit".
  tonal,

  /// `color-neutral-0` fill: back button floating over a map.
  onMap,

  /// Transparent 44px with a 20px muted icon: the (i) on purpose cards.
  info,
}

/// A circular button holding one icon. Every icon button needs a
/// [semanticLabel] because it has no visible text.
class PcIconButton extends StatelessWidget {
  /// Creates an icon button.
  const PcIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.variant = PcIconButtonVariant.standard,
    this.muted = false,
  });

  /// The icon, sized and colored by the button.
  final Widget icon;

  /// Announced by screen readers (the `aria-label`).
  final String semanticLabel;

  /// Called on tap. Null disables the button.
  final VoidCallback? onPressed;

  /// Fill and icon colors.
  final PcIconButtonVariant variant;

  /// Uses `color-text-muted` for a standard button's icon.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    final isInfo = variant == PcIconButtonVariant.info;
    final size = isInfo ? PcSizes.iconButtonCompact : PcSizes.iconButton;
    final iconSize = isInfo ? PcSizes.iconMd : PcSizes.iconLg;
    final (fill, iconColor) = _colors(colors);

    return PcFocusRing(
      borderRadius: size / 2,
      child: IconButton(
        onPressed: onPressed,
        iconSize: iconSize,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => fill != null && states.contains(WidgetState.disabled)
                ? colors.disabledBg
                : fill,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? colors.disabledText
                : iconColor,
          ),
          overlayColor: pcStateLayer(iconColor),
          fixedSize: WidgetStatePropertyAll(Size.square(size)),
          minimumSize: WidgetStatePropertyAll(Size.square(size)),
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          shape: const WidgetStatePropertyAll(CircleBorder()),
          splashFactory: NoSplash.splashFactory,
          visualDensity: VisualDensity.standard,
        ),
        icon: Semantics(
          label: semanticLabel,
          child: ExcludeSemantics(child: icon),
        ),
      ),
    );
  }

  (Color?, Color) _colors(PcColors colors) => switch (variant) {
    PcIconButtonVariant.standard => (
      null,
      muted ? colors.textMuted : colors.text,
    ),
    PcIconButtonVariant.filled => (colors.primary, colors.onPrimary),
    PcIconButtonVariant.tonal => (
      colors.secondaryContainer,
      colors.onSecondaryContainer,
    ),
    PcIconButtonVariant.onMap => (colors.surface, colors.text),
    PcIconButtonVariant.info => (null, colors.textMuted),
  };
}
