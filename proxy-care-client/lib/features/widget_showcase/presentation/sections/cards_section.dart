import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/tokens/pc_spacing.dart';
import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

const _priceRows = [
  PcSummaryRow(label: 'Visit, 4 hours', value: '₹1,200'),
  PcSummaryRow(label: 'Pickup and drop', value: '₹250'),
];

/// `PcCard` variants, `PcStatTile`, `PcRoleCard`, `PcExpandableCard` and
/// `PcSummary`.
class CardsSection extends StatelessWidget {
  /// Creates the section.
  const CardsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowcaseSection(
      title: 'Cards',
      description:
          'Flat cards with a border, never a shadow, and the components '
          'built on them. Mock amounts only.',
      specimens: [
        ShowcaseSpecimen(
          label: 'PcCard · variants',
          note: 'The last card is tappable as a whole.',
          child: ShowcaseColumn(
            children: [
              const PcCard(child: Text('Surface: 1px border')),
              const PcCard(
                variant: PcCardVariant.container,
                child: Text('Container: filled, no border'),
              ),
              const PcCard(
                variant: PcCardVariant.attention,
                child: Text('Attention: 2px warning border'),
              ),
              PcCard(
                onTap: () => showShowcaseFeedback(context, 'Card tapped'),
                child: const Text('Tappable surface card'),
              ),
            ],
          ),
        ),
        const ShowcaseSpecimen(
          label: 'PcStatTile',
          child: Row(
            children: [
              Expanded(
                child: PcStatTile(label: 'This week', value: '₹2,625'),
              ),
              SizedBox(width: PcSpacing.space3),
              Expanded(
                child: PcStatTile(label: 'Visits', value: '3'),
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcRoleCard',
          note: 'Primary and secondary styling.',
          child: ShowcaseColumn(
            children: [
              PcRoleCard(
                title: 'Primary role',
                subtitle: 'Supporting line',
                onTap: () => showShowcaseFeedback(context, 'Primary role'),
              ),
              PcRoleCard(
                title: 'Secondary role',
                subtitle: 'Supporting line',
                primary: false,
                onTap: () => showShowcaseFeedback(context, 'Secondary role'),
              ),
            ],
          ),
        ),
        const ShowcaseSpecimen(
          label: 'PcExpandableCard',
          note: 'Tap a card to expand or collapse it.',
          child: ShowcaseColumn(
            children: [
              PcExpandableCard(
                title: 'Collapsed at first',
                trailing: '₹1,450',
                child: PcSummary(rows: _priceRows),
              ),
              PcExpandableCard(
                title: 'Expanded at first',
                initiallyExpanded: true,
                child: Text('Any content can sit inside.'),
              ),
            ],
          ),
        ),
        const ShowcaseSpecimen(
          label: 'PcSummary',
          child: ShowcaseColumn(
            children: [
              PcSummary(
                rows: _priceRows,
                totalLabel: 'Total',
                totalValue: '₹1,450',
              ),
              PcSummary(rows: _priceRows),
            ],
          ),
        ),
      ],
    );
  }
}
