import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/pc_theme.dart';
import '../../../../core/theme/tokens/pc_spacing.dart';
import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

/// `PcBottomActionArea`, `PcConstrainedContent`, the window class, and the
/// interaction layers every control shares (`PcFocusRing`,
/// `pcStateLayer`).
class LayoutSection extends StatelessWidget {
  /// Creates the section.
  const LayoutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final width = MediaQuery.sizeOf(context).width.round();
    return ShowcaseSection(
      title: 'Layout',
      description:
          'Layout components and the interaction layers shared by every '
          'control. Resize the browser window to check the breakpoints.',
      specimens: [
        ShowcaseSpecimen(
          label: 'PcBottomActionArea',
          note: 'The one filled primary on top, a text button below.',
          child: PcBottomActionArea(
            children: [
              PcButton(
                label: 'Continue',
                fullWidth: true,
                onPressed: () => showShowcaseFeedback(context, 'Continue'),
              ),
              PcButton(
                label: 'Not now',
                variant: PcButtonVariant.text,
                fullWidth: true,
                onPressed: () => showShowcaseFeedback(context, 'Not now'),
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'Window class · PcBreakpoints',
          child: ShowcaseCaption(
            'Now: ${context.pcWindowClass.name} at ${width}dp. Expanded '
            'from ${pc.layout.expandedMinWidth.round()}dp; constrained '
            'content stops at ${pc.layout.maxContentWidth.round()}dp.',
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcFocusRing · pcStateLayer',
          note:
              'Hover a control for the 8% layer and press it for 12%. Press '
              'Tab to move keyboard focus and see the 2px focus ring.',
          child: ShowcaseWrap(
            children: [
              PcButton(
                label: 'Button',
                variant: PcButtonVariant.tonal,
                size: PcButtonSize.md,
                onPressed: () => showShowcaseFeedback(context, 'Button'),
              ),
              PcIconButton(
                icon: const Icon(Icons.add),
                semanticLabel: 'Add',
                variant: PcIconButtonVariant.filled,
                onPressed: () => showShowcaseFeedback(context, 'Add'),
              ),
              PcChoiceChip(
                label: 'Chip',
                selected: false,
                onTap: () => showShowcaseFeedback(context, 'Chip'),
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcConstrainedContent',
          note: 'The shaded column stops growing at the maximum width.',
          wide: true,
          child: PcConstrainedContent(
            child: ColoredBox(
              color: pc.colors.surfaceContainer,
              child: const Padding(
                padding: EdgeInsets.all(PcSpacing.space4),
                child: SizedBox(
                  width: double.infinity,
                  child: Text('Constrained content'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
