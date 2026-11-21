import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

/// `PcEmptyState` (with its dashed border) and `PcResultState`.
class EmptyStatesSection extends StatelessWidget {
  /// Creates the section.
  const EmptyStatesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowcaseSection(
      title: 'Empty and result states',
      description:
          'The dashed empty state for lists with nothing in them, and the '
          'centered result shown after a completed action.',
      specimens: [
        const ShowcaseSpecimen(
          label: 'PcEmptyState',
          note: 'With and without an icon.',
          child: ShowcaseColumn(
            children: [
              PcEmptyState(
                message: 'No visits yet. Booked visits show up here.',
                icon: Icon(Icons.event_busy_outlined),
              ),
              PcEmptyState(message: 'Nothing to show.'),
            ],
          ),
        ),
        const ShowcaseSpecimen(
          label: 'PcResultState · received',
          note: '72px disc, primary-200 tone.',
          child: PcResultState(
            icon: Icon(Icons.check),
            title: 'Request received',
            body: 'We will confirm within 15 minutes.',
            tone: PcResultTone.received,
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcResultState · completed, large',
          note: '80px disc with the single primary action.',
          child: PcResultState(
            icon: const Icon(Icons.verified_user_outlined),
            title: 'Visit completed',
            body: 'Thank you for using Proxy Care.',
            large: true,
            action: PcButton(
              label: 'Back to home',
              onPressed: () => showShowcaseFeedback(context, 'Back to home'),
            ),
          ),
        ),
      ],
    );
  }
}
