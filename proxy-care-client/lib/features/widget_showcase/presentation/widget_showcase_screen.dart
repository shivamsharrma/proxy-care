import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_density.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/pc_theme.dart';
import '../../../core/theme/tokens/pc_spacing.dart';
import '../../../core/theme/tokens/pc_typography.dart';
import '../../../shared/widgets/design_system.dart';
import 'sections/avatars_section.dart';
import 'sections/buttons_section.dart';
import 'sections/cards_section.dart';
import 'sections/empty_states_section.dart';
import 'sections/feedback_section.dart';
import 'sections/icons_section.dart';
import 'sections/inputs_section.dart';
import 'sections/layout_section.dart';
import 'sections/lists_section.dart';
import 'sections/loading_section.dart';
import 'sections/navigation_section.dart';
import 'sections/overlays_section.dart';
import 'sections/selection_section.dart';
import 'sections/typography_section.dart';
import 'showcase_category.dart';
import 'widgets/showcase_layout.dart';

/// Every reusable design-system component with its variants, sizes and
/// states, for visual inspection and interaction testing.
///
/// Development only: the route exists only in builds that enable the
/// `widget_showcase` feature flag outside production (see
/// `WidgetShowcaseRoutes`). Interactions use in-memory state; nothing is
/// sent to an API or saved.
class WidgetShowcaseScreen extends StatefulWidget {
  /// Creates the showcase.
  const WidgetShowcaseScreen({super.key});

  @override
  State<WidgetShowcaseScreen> createState() => _WidgetShowcaseScreenState();
}

class _WidgetShowcaseScreenState extends State<WidgetShowcaseScreen> {
  AppDensity _density = AppDensity.standard;
  ShowcaseCategory? _category;

  @override
  Widget build(BuildContext context) {
    // The density is previewed locally; the app-wide density is untouched.
    return Theme(
      data: buildProxyCareTheme(_density),
      child: _ShowcasePage(
        density: _density,
        category: _category,
        onDensityChanged: (density) => setState(() => _density = density),
        onCategoryChanged: (category) => setState(() => _category = category),
      ),
    );
  }
}

class _ShowcasePage extends StatelessWidget {
  const _ShowcasePage({
    required this.density,
    required this.category,
    required this.onDensityChanged,
    required this.onCategoryChanged,
  });

  final AppDensity density;
  final ShowcaseCategory? category;
  final ValueChanged<AppDensity> onDensityChanged;
  final ValueChanged<ShowcaseCategory?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final selected = category;
    final categories = selected == null ? ShowcaseCategory.values : [selected];
    return Scaffold(
      backgroundColor: context.pc.colors.bg,
      appBar: const PcTopAppBar(
        title: 'Widget showcase',
        leading: PcAppBarLeading.none,
      ),
      body: ListView(
        padding: const EdgeInsets.all(PcSpacing.space4),
        children: [
          PcConstrainedContent(
            maxWidth: showcaseMaxWidth,
            child: _ShowcaseControls(
              density: density,
              category: category,
              onDensityChanged: onDensityChanged,
              onCategoryChanged: onCategoryChanged,
            ),
          ),
          for (final shown in categories) ...[
            const SizedBox(height: PcSpacing.space10),
            PcConstrainedContent(
              key: ValueKey(shown),
              maxWidth: showcaseMaxWidth,
              child: _sectionFor(shown),
            ),
          ],
          const SizedBox(height: PcSpacing.space12),
        ],
      ),
    );
  }

  static Widget _sectionFor(ShowcaseCategory category) => switch (category) {
    ShowcaseCategory.buttons => const ButtonsSection(),
    ShowcaseCategory.inputs => const InputsSection(),
    ShowcaseCategory.selection => const SelectionSection(),
    ShowcaseCategory.cards => const CardsSection(),
    ShowcaseCategory.lists => const ListsSection(),
    ShowcaseCategory.navigation => const NavigationSection(),
    ShowcaseCategory.overlays => const OverlaysSection(),
    ShowcaseCategory.feedback => const FeedbackSection(),
    ShowcaseCategory.loading => const LoadingSection(),
    ShowcaseCategory.emptyStates => const EmptyStatesSection(),
    ShowcaseCategory.avatars => const AvatarsSection(),
    ShowcaseCategory.typography => const TypographySection(),
    ShowcaseCategory.icons => const IconsSection(),
    ShowcaseCategory.layout => const LayoutSection(),
  };
}

class _ShowcaseControls extends StatelessWidget {
  const _ShowcaseControls({
    required this.density,
    required this.category,
    required this.onDensityChanged,
    required this.onCategoryChanged,
  });

  final AppDensity density;
  final ShowcaseCategory? category;
  final ValueChanged<AppDensity> onDensityChanged;
  final ValueChanged<ShowcaseCategory?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final width = MediaQuery.sizeOf(context).width.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Proxy Care design system',
          style: PcTypeScale.h1.copyWith(color: pc.colors.text),
        ),
        const SizedBox(height: PcSpacing.space2),
        Text(
          'Every reusable component from lib/shared/widgets, with its '
          'variants, sizes and states. Interactions use in-memory mock data '
          'only: nothing is sent to an API or saved.',
          style: pc.text.bodyMd.copyWith(color: pc.colors.textMuted),
        ),
        const SizedBox(height: PcSpacing.space1),
        ShowcaseCaption(
          'Window: ${context.pcWindowClass.name}, ${width}dp wide.',
        ),
        const SizedBox(height: PcSpacing.space6),
        const PcSectionLabel('Density'),
        const SizedBox(height: PcSpacing.space2),
        PcSegmentedButton<AppDensity>(
          segments: const [
            PcSegment(value: AppDensity.standard, label: 'Family'),
            PcSegment(value: AppDensity.comfortable, label: 'Caretaker'),
          ],
          selected: density,
          onChanged: onDensityChanged,
        ),
        const SizedBox(height: PcSpacing.space6),
        const PcSectionLabel('Category'),
        const SizedBox(height: PcSpacing.space2),
        ShowcaseWrap(
          children: [
            PcChoiceChip(
              label: 'All',
              selected: category == null,
              onTap: () => onCategoryChanged(null),
            ),
            for (final value in ShowcaseCategory.values)
              PcChoiceChip(
                label: value.label,
                selected: category == value,
                onTap: () => onCategoryChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}
