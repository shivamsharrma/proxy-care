import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/pc_theme.dart';
import '../../../../core/theme/tokens/pc_typography.dart';
import '../widgets/showcase_layout.dart';

const _sample = 'Book help for Monday';

const _familyScale = <(String, TextStyle)>[
  ('display', PcTypeScale.display),
  ('h1', PcTypeScale.h1),
  ('h2', PcTypeScale.h2),
  ('h3', PcTypeScale.h3),
  ('titleMd', PcTypeScale.titleMd),
  ('titleSm', PcTypeScale.titleSm),
  ('bodyLg', PcTypeScale.bodyLg),
  ('bodyMd', PcTypeScale.bodyMd),
  ('bodySm', PcTypeScale.bodySm),
  ('listTitle', PcTypeScale.listTitle),
  ('listMeta', PcTypeScale.listMeta),
  ('button', PcTypeScale.button),
  ('buttonSm', PcTypeScale.buttonSm),
  ('sectionLabel', PcTypeScale.sectionLabel),
  ('fieldLabel', PcTypeScale.fieldLabel),
  ('overline', PcTypeScale.overline),
  ('badge', PcTypeScale.badge),
  ('navLabel', PcTypeScale.navLabel),
  ('micro', PcTypeScale.micro),
];

const _numericScale = <(String, TextStyle)>[
  ('amountXl', PcTypeScale.amountXl),
  ('amountLg', PcTypeScale.amountLg),
  ('amountMd', PcTypeScale.amountMd),
  ('otpDigit', PcTypeScale.otpDigit),
  ('code', PcTypeScale.code),
];

const _caretakerScale = <(String, TextStyle)>[
  ('cBodyLg', PcTypeScale.cBodyLg),
  ('cBodyOption', PcTypeScale.cBodyOption),
  ('cBodyMd', PcTypeScale.cBodyMd),
  ('cSectionLabel', PcTypeScale.cSectionLabel),
  ('cButton', PcTypeScale.cButton),
  ('cFieldLabel', PcTypeScale.cFieldLabel),
  ('cHelper', PcTypeScale.cHelper),
  ('cNavLabel', PcTypeScale.cNavLabel),
  ('cBadge', PcTypeScale.cBadge),
  ('sheetTitle', PcTypeScale.sheetTitle),
];

/// The type scale (`PcTypeScale`) and the density text roles
/// (`PcTextStyles`, read from the theme).
class TypographySection extends StatelessWidget {
  /// Creates the section.
  const TypographySection({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.pc.text;
    final densityRoles = <(String, TextStyle)>[
      ('bodyLg', text.bodyLg),
      ('bodyMd', text.bodyMd),
      ('optionLabel', text.optionLabel),
      ('sectionLabel', text.sectionLabel),
      ('fieldLabel', text.fieldLabel),
      ('helper', text.helper),
      ('navLabel', text.navLabel),
      ('badge', text.badge),
      ('stepCaption', text.stepCaption),
      ('emptyState', text.emptyState),
    ];
    return ShowcaseSection(
      title: 'Typography',
      description:
          'Every type token with its size and weight. Latin text uses the '
          'platform font; Devanagari uses the bundled Noto Sans Devanagari.',
      specimens: [
        const ShowcaseSpecimen(
          label: 'PcTypeScale · text',
          child: _TypeList(styles: _familyScale),
        ),
        const ShowcaseSpecimen(
          label: 'PcTypeScale · amounts and codes',
          child: _TypeList(styles: _numericScale, sample: '₹1,450 · 482916'),
        ),
        const ShowcaseSpecimen(
          label: 'PcTypeScale · caretaker (c-) and sheet',
          child: _TypeList(styles: _caretakerScale),
        ),
        ShowcaseSpecimen(
          label: 'PcTextStyles · density roles',
          note: 'Changes with the Family / Caretaker density switch.',
          child: _TypeList(styles: densityRoles),
        ),
        const ShowcaseSpecimen(
          label: 'Devanagari',
          child: _TypeList(
            styles: [
              ('bodyLg', PcTypeScale.bodyLg),
              ('h2', PcTypeScale.h2),
            ],
            sample: 'देखभाल करने वाला सोमवार को आएगा',
          ),
        ),
      ],
    );
  }
}

class _TypeList extends StatelessWidget {
  const _TypeList({required this.styles, this.sample = _sample});

  final List<(String, TextStyle)> styles;
  final String sample;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    return ShowcaseColumn(
      children: [
        for (final (name, style) in styles)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShowcaseCaption(
                '$name · ${style.fontSize?.round()}px · '
                'weight ${style.fontWeight?.value ?? 400}',
              ),
              Text(sample, style: style.copyWith(color: colors.text)),
            ],
          ),
      ],
    );
  }
}
