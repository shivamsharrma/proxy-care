import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_typography.dart';

/// Avatar sizes from the Avatar page.
enum PcAvatarSize {
  /// 36px with 14px initials: context strips.
  sm(PcSizes.avatarSm, 14),

  /// 44px with 16px initials: compact cards.
  md(PcSizes.avatarMd, 16),

  /// 48px with 18px initials: selection and caretaker cards.
  lg(PcSizes.avatarLg, 18);

  const PcAvatarSize(this.diameter, this.fontSize);

  /// Circle diameter.
  final double diameter;

  /// Initials size.
  final double fontSize;
}

/// People are shown as initials in a circle: `color-secondary-100` fill,
/// `color-secondary-900` initials at weight 500. Never photos in lists,
/// never squares.
class PcAvatar extends StatelessWidget {
  /// Creates an initials avatar.
  const PcAvatar({
    super.key,
    required this.initials,
    this.size = PcAvatarSize.md,
    this.semanticLabel,
  });

  /// One or two letters.
  final String initials;

  /// Diameter and initials size.
  final PcAvatarSize size;

  /// The person's name for screen readers. Null when the name is already
  /// next to the avatar.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    final avatar = Container(
      width: size.diameter,
      height: size.diameter,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: PcTypeScale.titleSm.copyWith(
          fontSize: size.fontSize,
          height: 1,
          color: colors.onSecondaryContainer,
        ),
      ),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: avatar);
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: avatar,
    );
  }
}
