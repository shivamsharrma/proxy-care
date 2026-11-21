import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_colors.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';

/// A status badge (Badge page): 28px (32 in caretaker density),
/// `radius-md`, an 8px dot in the tone accent and the label in the tone's
/// on-color, so status never relies on color alone.
///
/// Status color is fixed: pending / in progress = [PcTone.warning], done /
/// paid = [PcTone.success], failed / blocked = [PcTone.error], neutral info
/// = [PcTone.neutral].
class PcStatusBadge extends StatelessWidget {
  /// Creates a status badge.
  const PcStatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.live = false,
  });

  /// Status text ("At hospital · OPD started").
  final String label;

  /// Status tone.
  final PcTone tone;

  /// Announces changes politely (`role="status"`) for badges that update
  /// while the screen is open.
  final bool live;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors.tone(tone);
    final textColor = tone == PcTone.neutral
        ? pc.colors.text
        : colors.onContainer;
    return Semantics(
      liveRegion: live,
      container: true,
      child: Container(
        height: pc.metrics.badgeHeight,
        padding: const EdgeInsetsDirectional.only(
          start: PcSpacing.space2,
          end: _badgeEndPadding,
        ),
        decoration: BoxDecoration(
          color: colors.container,
          borderRadius: const BorderRadius.all(Radius.circular(PcRadii.md)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: PcSizes.statusDot,
              height: PcSizes.statusDot,
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: _badgeGap),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pc.text.badge.copyWith(color: textColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge page values that are not on the spacing scale ("padding 0 10 0 8,
/// gap 6"). Kept as specified for this component; see
/// docs/design-system-mapping.md.
const double _badgeEndPadding = 10;
const double _badgeGap = 6;

/// A 24px tag for a price attribute (Badge page): `radius-md`, padding 0 8,
/// 12/500. Uses a tone's container and on-color; neutral by default.
class PcTag extends StatelessWidget {
  /// Creates a tag.
  const PcTag({super.key, required this.label, this.tone = PcTone.neutral});

  /// Tag text.
  final String label;

  /// Fill and text color.
  final PcTone tone;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors.tone(tone);
    final textColor = tone == PcTone.neutral
        ? pc.colors.text
        : colors.onContainer;
    return Container(
      height: PcSizes.tag,
      padding: const EdgeInsets.symmetric(horizontal: PcSpacing.space2),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: const BorderRadius.all(Radius.circular(PcRadii.md)),
      ),
      // widthFactor 1: hug the label instead of filling a loose row.
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          style: PcTypeScale.overline.copyWith(
            color: textColor,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

/// A 20px count badge (Badge page): `color-error-500` pill with white 12px
/// text, at least 20px wide.
class PcCountBadge extends StatelessWidget {
  /// Creates a count badge.
  const PcCountBadge({super.key, required this.count, this.semanticLabel});

  /// The count shown.
  final int count;

  /// Read instead of the bare number ("3 pending requests").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Container(
        height: PcSizes.countBadge,
        constraints: const BoxConstraints(minWidth: PcSizes.countBadge),
        padding: const EdgeInsets.symmetric(horizontal: PcSpacing.space1),
        decoration: ShapeDecoration(
          color: colors.errorTone.accent,
          shape: const StadiumBorder(),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            '$count',
            style: PcTypeScale.overline.copyWith(
              color: colors.onPrimary,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}
