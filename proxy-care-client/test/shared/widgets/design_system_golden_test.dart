import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/theme/app_density.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_colors.dart';
import 'package:proxy_care_client/shared/widgets/design_system.dart';

import '../../helpers/golden.dart';

// Goldens of documented design-system components (docs/design-system-
// mapping.md → claude/proxycare-design-system.md). Each image shows the
// variants and states the design system specifies; review a changed image
// against that document before blessing it.

void _noop() {}

void main() {
  goldenTest(
    'buttons: every variant, disabled and loading',
    name: 'buttons',
    children: [
      for (final variant in PcButtonVariant.values)
        PcButton(label: variant.name, variant: variant, onPressed: _noop),
      const PcButton(
        label: 'disabled',
        onPressed: null,
        disabledReason: 'reason',
      ),
      const PcButton(label: 'loading', onPressed: _noop, loading: true),
    ],
  );

  goldenTest(
    'buttons at comfortable (caretaker) density',
    name: 'buttons_comfortable',
    density: AppDensity.comfortable,
    children: const [
      PcButton(label: 'filled', onPressed: _noop),
      PcButton(
        label: 'outlined',
        variant: PcButtonVariant.outlined,
        onPressed: _noop,
      ),
    ],
  );

  goldenTest(
    'badges and banners in every tone',
    name: 'badges_banners',
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final tone in PcTone.values)
            PcStatusBadge(label: tone.name, tone: tone),
          const PcTag(label: 'tag'),
          const PcCountBadge(count: 3, semanticLabel: '3 new'),
        ],
      ),
      const PcBanner.note(message: 'note'),
      for (final tone in [PcTone.info, PcTone.warning, PcTone.success])
        PcBanner.status(title: tone.name, body: 'body', tone: tone),
    ],
  );

  goldenTest(
    'text fields and chips in their states',
    name: 'inputs',
    children: const [
      PcTextField(label: 'default', helper: 'helper'),
      PcTextField(label: 'error', error: 'error'),
      PcTextField(label: 'disabled', enabled: false),
      Wrap(
        spacing: 8,
        children: [
          PcChoiceChip(label: 'on', selected: true, onTap: _noop),
          PcChoiceChip(label: 'off', selected: false, onTap: _noop),
          PcChoiceChip(
            label: 'slot',
            selected: false,
            onTap: _noop,
            type: PcChipType.timeSlot,
          ),
        ],
      ),
    ],
  );

  goldenTest(
    'cards: surface, attention, stat tile and summary',
    name: 'cards',
    children: const [
      PcCard(child: Text('surface')),
      PcCard(variant: PcCardVariant.attention, child: Text('attention')),
      PcStatTile(label: 'label', value: '₹2,625'),
      PcCard(
        child: PcSummary(
          rows: [
            PcSummaryRow(label: 'one', value: '₹1,249'),
            PcSummaryRow(label: 'two', value: '−₹849'),
          ],
          totalLabel: 'total',
          totalValue: '₹400',
        ),
      ),
    ],
  );
}
