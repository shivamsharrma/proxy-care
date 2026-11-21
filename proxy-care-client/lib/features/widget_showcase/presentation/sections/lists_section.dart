import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/tokens/pc_colors.dart';
import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

/// `PcListGroup`, `PcListRow`, `PcIconWell` and `PcSectionLabel`.
class ListsSection extends StatelessWidget {
  /// Creates the section.
  const ListsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowcaseSection(
      title: 'Lists',
      description:
          'Grouped rows with dividers. A row with onTap shows a chevron; a '
          'row without it is static.',
      specimens: [
        ShowcaseSpecimen(
          label: 'PcListGroup · PcListRow',
          child: PcListGroup(
            children: [
              PcListRow(
                title: 'Linked row with amount and status',
                meta: 'Mon 17 · 10:00 AM',
                leading: const PcIconWell(icon: Icon(Icons.event_outlined)),
                trailingAmount: '₹1,200',
                trailingStatus: const PcStatusBadge(
                  label: 'Paid',
                  tone: PcTone.success,
                ),
                onTap: () => showShowcaseFeedback(context, 'First row tapped'),
              ),
              PcListRow(
                title: 'Pending row',
                meta: 'Tue 18 · 2:30 PM',
                leading: const PcIconWell(
                  icon: Icon(Icons.schedule),
                  tone: PcTone.warning,
                ),
                trailingAmount: '₹300',
                trailingStatus: const PcStatusBadge(
                  label: 'Pending',
                  tone: PcTone.warning,
                ),
                onTap: () => showShowcaseFeedback(context, 'Second row tapped'),
              ),
              const PcListRow(
                title: 'Static row',
                meta: 'No onTap, so no chevron',
              ),
              const PcListRow(title: 'Title only'),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcIconWell · tones',
          child: ShowcaseWrap(
            children: [
              for (final tone in PcTone.values)
                PcIconWell(icon: const Icon(Icons.check), tone: tone),
            ],
          ),
        ),
        const ShowcaseSpecimen(
          label: 'PcSectionLabel',
          child: ShowcaseColumn(
            children: [
              PcSectionLabel('Upcoming'),
              PcSectionLabel(
                'With a trailing badge',
                trailing: PcCountBadge(count: 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
