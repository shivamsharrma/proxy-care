import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_spacing.dart';

/// The bottom action area (section 3 and usage rules): padded 16 / 24 / 24
/// (top / sides / bottom), buttons full-width and stacked 8px apart, the
/// one filled primary on top and a text button below. Keeps clear of the
/// system gesture area and the keyboard inset handled by `Scaffold`.
class PcBottomActionArea extends StatelessWidget {
  /// Creates an action area.
  const PcBottomActionArea({super.key, required this.children});

  /// Full-width buttons, primary first.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PcSpacing.textInset,
          PcSpacing.space4,
          PcSpacing.textInset,
          PcSpacing.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: PcSpacing.space2),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Centers [child] and limits it to the theme's maximum content width
/// (provisionally 720dp) on wide windows such as tablets. On phones it has
/// no effect.
///
/// Use it on content surfaces that read badly when stretched (forms,
/// reading columns, the bottom action area); full-bleed surfaces such as
/// maps, app bars and navigation bars stay full width.
class PcConstrainedContent extends StatelessWidget {
  /// Creates a constrained content surface.
  const PcConstrainedContent({super.key, required this.child, this.maxWidth});

  /// The content.
  final Widget child;

  /// Overrides the theme's maximum content width.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? context.pc.layout.maxContentWidth,
        ),
        child: child,
      ),
    );
  }
}
