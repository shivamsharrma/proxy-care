import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';
import 'pc_state_layer.dart';

/// One option of a [PcSegmentedButton].
final class PcSegment<T> {
  /// Creates a segment.
  const PcSegment({required this.value, required this.label});

  /// Value reported when selected.
  final T value;

  /// Visible label.
  final String label;
}

/// A 48px pill split into equal segments (Chip page, decision #28): 1px
/// `color-outline` container and dividers, labels 16/500 `color-text`, the
/// selected segment `color-secondary-100` with a check.
class PcSegmentedButton<T> extends StatelessWidget {
  /// Creates a segmented button.
  const PcSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// The options, left to right.
  final List<PcSegment<T>> segments;

  /// The selected value.
  final T selected;

  /// Called with the tapped segment's value.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    return Container(
      height: PcSizes.segmented,
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(color: colors.outline, width: PcBorders.thin),
        ),
      ),
      child: ClipPath(
        clipper: const ShapeBorderClipper(shape: StadiumBorder()),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: PcBorders.thin,
                  thickness: PcBorders.thin,
                  color: colors.outline,
                ),
              Expanded(child: _segment(context, segments[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, PcSegment<T> segment) {
    final colors = context.pc.colors;
    final isSelected = segment.value == selected;
    final labelColor = isSelected ? colors.onSecondaryContainer : colors.text;
    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: isSelected ? colors.secondaryContainer : const Color(0x00000000),
        child: InkWell(
          onTap: () => onChanged(segment.value),
          overlayColor: pcStateLayer(labelColor),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(
                    Icons.check,
                    size: PcSizes.iconSm,
                    color: labelColor,
                  ),
                  const SizedBox(width: PcSpacing.space2),
                ],
                Flexible(
                  child: Text(
                    segment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PcTypeScale.button.copyWith(color: labelColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
