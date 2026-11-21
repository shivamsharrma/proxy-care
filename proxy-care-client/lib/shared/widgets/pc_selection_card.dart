import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_colors.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import 'pc_focus_ring.dart';
import 'pc_state_layer.dart';

/// Border, fill and accent of a selection card in its current state.
final class _SelectionStyle {
  const _SelectionStyle(this.fill, this.border, this.borderWidth, this.accent);

  factory _SelectionStyle.of(
    PcColors colors, {
    required bool selected,
    required bool urgent,
  }) {
    if (!selected) {
      return _SelectionStyle(
        colors.surface,
        colors.border,
        PcBorders.thin,
        colors.primary,
      );
    }
    return urgent
        ? _SelectionStyle(
            colors.errorSelected,
            colors.errorTone.accent,
            PcBorders.thick,
            colors.errorTone.accent,
          )
        : _SelectionStyle(
            colors.primarySelected,
            colors.primary,
            PcBorders.thick,
            colors.primary,
          );
  }

  final Color fill;
  final Color border;
  final double borderWidth;
  final Color accent;
}

Widget _selectionSurface(
  BuildContext context, {
  required _SelectionStyle style,
  required VoidCallback? onTap,
  required EdgeInsets padding,
  required Widget child,
}) {
  final shape = RoundedRectangleBorder(
    borderRadius: const BorderRadius.all(Radius.circular(PcRadii.xl)),
    side: BorderSide(color: style.border, width: style.borderWidth),
  );
  return PcFocusRing(
    borderRadius: PcRadii.xl,
    child: Material(
      color: style.fill,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        overlayColor: pcStateLayer(context.pc.colors.text),
        // CSS puts the border outside the padding (and drops the padding by
        // 1px for a 2px border); a Flutter shape paints it inside, so the
        // padding adds the 1px base border and content never moves.
        child: Padding(
          padding: padding + const EdgeInsets.all(PcBorders.thin),
          child: child,
        ),
      ),
    ),
  );
}

/// A full-width card that is itself a radio option (SelectionCard page):
/// people, mobility level, dispute reasons. Stack cards 8px apart.
///
/// Selected: 2px `color-primary-500` border on `color-primary-50`; the
/// urgent option (Emergency) uses `color-error-500` on `color-error-50`.
class PcSelectionCard extends StatelessWidget {
  /// Creates a radio card.
  const PcSelectionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.meta,
    this.leading,
    this.urgent = false,
  });

  /// Option label.
  final String title;

  /// Supporting line in `body-md` muted.
  final String? meta;

  /// Leading avatar or icon tile.
  final Widget? leading;

  /// Whether this option is chosen.
  final bool selected;

  /// Called on tap.
  final VoidCallback? onTap;

  /// Uses the error tone when selected (Emergency).
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors;
    final style = _SelectionStyle.of(
      colors,
      selected: selected,
      urgent: urgent,
    );

    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: onTap != null,
      onTap: onTap,
      label: meta == null ? title : '$title, $meta',
      excludeSemantics: true,
      child: _selectionSurface(
        context,
        style: style,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          vertical: PcSpacing.space3,
          horizontal: PcSpacing.space4,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight:
                PcSizes.selectionCardMin -
                2 * (PcSpacing.space3 + PcBorders.thin),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: PcSpacing.space3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: pc.text.optionLabel.copyWith(color: colors.text),
                    ),
                    if (meta != null)
                      Text(
                        meta!,
                        style: pc.text.bodyMd.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: PcSpacing.space3),
              _RadioIndicator(selected: selected, accent: style.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  const _RadioIndicator({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ring = selected ? accent : context.pc.colors.textMuted;
    return Container(
      width: PcSizes.radio,
      height: PcSizes.radio,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring, width: PcBorders.thick),
      ),
      child: selected
          ? Container(
              width: PcSizes.radioDot,
              height: PcSizes.radioDot,
              decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
            )
          : null,
    );
  }
}

/// A checkbox tile for multi-select choices such as visit purpose
/// (SelectionCard page). Purpose tiles sit in a 2-column grid with a 12px
/// gap.
///
/// Selected: the icon tile turns `color-primary-500` with a white icon and
/// a 20px check badge with a 2px white ring appears top-right.
class PcCheckboxTile extends StatelessWidget {
  /// Creates a checkbox tile.
  const PcCheckboxTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.meta,
    this.urgent = false,
  });

  /// Icon shown in the 40px tile.
  final Widget icon;

  /// Option label.
  final String title;

  /// Supporting line.
  final String? meta;

  /// Whether this option is ticked.
  final bool selected;

  /// Called on tap.
  final VoidCallback? onTap;

  /// Uses the error tone (Emergency).
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors;
    final style = _SelectionStyle.of(
      colors,
      selected: selected,
      urgent: urgent,
    );
    final tone = urgent ? colors.errorTone : null;
    final tileFill = selected
        ? style.accent
        : tone?.container ?? colors.secondaryContainer;
    final tileIcon = selected
        ? colors.onPrimary
        : tone?.accent ?? colors.onSecondaryContainer;

    return Semantics(
      container: true,
      checked: selected,
      enabled: onTap != null,
      onTap: onTap,
      label: meta == null ? title : '$title, $meta',
      excludeSemantics: true,
      child: Stack(
        children: [
          _selectionSurface(
            context,
            style: style,
            onTap: onTap,
            padding: const EdgeInsets.all(PcSpacing.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: PcSizes.iconWell,
                  height: PcSizes.iconWell,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tileFill,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(PcRadii.lg),
                    ),
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(size: PcSizes.iconMd, color: tileIcon),
                    child: icon,
                  ),
                ),
                const SizedBox(height: PcSpacing.space3),
                Text(
                  title,
                  style: pc.text.optionLabel.copyWith(color: colors.text),
                ),
                if (meta != null)
                  Text(
                    meta!,
                    style: pc.text.bodyMd.copyWith(color: colors.textMuted),
                  ),
              ],
            ),
          ),
          if (selected)
            PositionedDirectional(
              top: PcSpacing.space3,
              end: PcSpacing.space3,
              child: Container(
                width: PcSizes.checkBadge,
                height: PcSizes.checkBadge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.accent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.onPrimary,
                    width: PcBorders.thick,
                  ),
                ),
                child: Icon(
                  Icons.check,
                  size: PcSizes.checkBadge - 2 * PcBorders.thick,
                  color: colors.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
