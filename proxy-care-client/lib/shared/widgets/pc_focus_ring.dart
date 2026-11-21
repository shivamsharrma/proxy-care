import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_shape.dart';

/// Draws the design system's keyboard focus ring around [child]: 2px
/// `color-primary-500`, 2px outside the control, following its corners.
///
/// The ring shows while anything inside [child] has focus and the user is
/// navigating with a keyboard (Flutter's traditional highlight mode), so a
/// tap does not leave a ring behind. It never changes layout.
class PcFocusRing extends StatefulWidget {
  /// Creates a focus ring.
  const PcFocusRing({
    super.key,
    required this.borderRadius,
    required this.child,
  });

  /// Corner radius of the control. The ring adds its offset to it.
  final double borderRadius;

  /// The focusable control.
  final Widget child;

  /// Gap between the control and the ring.
  static const double offset = PcBorders.thick;

  @override
  State<PcFocusRing> createState() => _PcFocusRingState();
}

class _PcFocusRingState extends State<PcFocusRing> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    super.dispose();
  }

  void _onHighlightModeChanged(FocusHighlightMode mode) {
    if (_focused) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const outset = PcFocusRing.offset + PcBorders.thick;
    final showRing =
        _focused &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (showRing)
            Positioned(
              left: -outset,
              top: -outset,
              right: -outset,
              bottom: -outset,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: context.pc.colors.primary,
                      width: PcBorders.thick,
                    ),
                    borderRadius: BorderRadius.circular(
                      widget.borderRadius + outset,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
