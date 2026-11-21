import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/pc_theme.dart';
import '../../../../core/theme/tokens/pc_sizes.dart';
import '../../../../core/theme/tokens/pc_spacing.dart';
import '../widgets/showcase_layout.dart';

/// The icons the components draw themselves (design-system decision A4:
/// Flutter's built-in Material icons).
const _componentIcons = <(String, IconData)>[
  ('check', Icons.check),
  ('arrow_back', Icons.arrow_back),
  ('close', Icons.close),
  ('chevron_right', Icons.chevron_right),
  ('expand_more', Icons.expand_more),
  ('error_outline', Icons.error_outline),
];

/// The icon size tokens.
const _iconSizes = <(String, double)>[
  ('iconSm', PcSizes.iconSm),
  ('iconMd', PcSizes.iconMd),
  ('iconLg', PcSizes.iconLg),
  ('iconEmptyState', PcSizes.iconEmptyState),
  ('iconResultSm', PcSizes.iconResultSm),
  ('iconResultLg', PcSizes.iconResultLg),
];

/// The icon set and the icon size tokens.
class IconsSection extends StatelessWidget {
  /// Creates the section.
  const IconsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final color = context.pc.colors.text;
    return ShowcaseSection(
      title: 'Icons',
      description:
          'The components use the built-in Material icons (decision A4 in '
          'docs/design-system-mapping.md). The app has no custom or Lucide '
          'icon set.',
      specimens: [
        ShowcaseSpecimen(
          label: 'Component icons · iconSm, iconMd, iconLg',
          child: ShowcaseColumn(
            children: [
              for (final (name, icon) in _componentIcons)
                Row(
                  children: [
                    Icon(icon, size: PcSizes.iconSm, color: color),
                    Icon(icon, size: PcSizes.iconMd, color: color),
                    Icon(icon, size: PcSizes.iconLg, color: color),
                    const SizedBox(width: PcSpacing.space3),
                    Expanded(child: ShowcaseCaption('Icons.$name')),
                  ],
                ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'Icon size tokens',
          child: ShowcaseWrap(
            children: [
              for (final (name, size) in _iconSizes)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: size, color: color),
                    ShowcaseCaption('$name ${size.round()}'),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
