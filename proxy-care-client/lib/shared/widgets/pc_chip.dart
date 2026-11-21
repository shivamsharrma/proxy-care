import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_states.dart';
import '../../core/theme/tokens/pc_typography.dart';
import 'pc_focus_ring.dart';
import 'pc_state_layer.dart';

/// Chip types from the Chip page.
enum PcChipType {
  /// 32px choice chip.
  choice,

  /// 36px time-slot chip on `color-surface`; selected like a choice chip
  /// (decision #4).
  timeSlot,

  /// 32px language toggle with 12px side padding. Devanagari labels render
  /// in Noto Sans Devanagari through the font fallback.
  language,
}

/// A compact choice control. Unselected: 1px `color-outline`, muted label.
/// Selected: `color-secondary-100` fill, no border, 18px check.
///
/// Chips wrap with an 8px gap (`PcSpacing.space2`).
class PcChoiceChip extends StatelessWidget {
  /// Creates a chip.
  const PcChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.type = PcChipType.choice,
    this.inGroup = true,
  });

  /// Visible label.
  final String label;

  /// Whether the chip is selected.
  final bool selected;

  /// Called on tap. Null disables the chip (38% opacity).
  final VoidCallback? onTap;

  /// Size and unselected fill.
  final PcChipType type;

  /// Whether the chip is one of a single-choice group (radio semantics);
  /// false announces it as a toggle.
  final bool inGroup;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    final height = type == PcChipType.timeSlot
        ? PcSizes.timeSlotChip
        : PcSizes.chip;
    final side = type == PcChipType.language
        ? PcSpacing.space3
        : PcSpacing.space4;
    final labelColor = selected
        ? colors.onSecondaryContainer
        : colors.textMuted;
    final fill = selected
        ? colors.secondaryContainer
        : type == PcChipType.timeSlot
        ? colors.surface
        : const Color(0x00000000);
    final shape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(PcRadii.md)),
      side: selected
          ? BorderSide.none
          : BorderSide(color: colors.outline, width: PcBorders.thin),
    );

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: inGroup,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? PcOpacity.disabled : 1,
        child: PcFocusRing(
          borderRadius: PcRadii.md,
          child: Material(
            color: fill,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: shape,
              overlayColor: pcStateLayer(labelColor),
              child: Container(
                height: height,
                padding: EdgeInsetsDirectional.only(
                  start: selected ? PcSpacing.space2 : side,
                  end: side,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selected) ...[
                      Icon(
                        Icons.check,
                        size: PcSizes.iconSm,
                        color: labelColor,
                      ),
                      const SizedBox(width: PcSpacing.space2),
                    ],
                    Text(
                      label,
                      style: PcTypeScale.buttonSm.copyWith(color: labelColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 60×76 cell in the horizontal date strip. Selected cells are filled
/// with `color-primary-500` and white text (a large picker, so a filled
/// selection is allowed). Cells sit 8px apart.
class PcDateCell extends StatelessWidget {
  /// Creates a date cell.
  const PcDateCell({
    super.key,
    required this.weekday,
    required this.day,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  /// Short weekday label ("Mon").
  final String weekday;

  /// Day number ("14").
  final String day;

  /// Whether this date is selected.
  final bool selected;

  /// Called on tap. Null disables the cell (38% opacity).
  final VoidCallback? onTap;

  /// Full date for screen readers ("Monday 14 November"). Defaults to the
  /// visible labels.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    final textColor = selected ? colors.onPrimary : colors.text;
    final shape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.all(Radius.circular(PcRadii.xl)),
      side: selected
          ? BorderSide.none
          : BorderSide(color: colors.outlineVariant, width: PcBorders.thin),
    );

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      enabled: onTap != null,
      label: semanticLabel ?? '$weekday $day',
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null ? PcOpacity.disabled : 1,
        child: PcFocusRing(
          borderRadius: PcRadii.xl,
          child: Material(
            color: selected ? colors.primary : colors.surface,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: shape,
              overlayColor: pcStateLayer(textColor),
              child: SizedBox(
                width: PcSizes.dateCellWidth,
                height: PcSizes.dateCellHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekday,
                      style: PcTypeScale.bodySm.copyWith(color: textColor),
                    ),
                    Text(
                      day,
                      style: PcTypeScale.amountMd.copyWith(color: textColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
