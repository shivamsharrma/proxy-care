import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

const _destinations = [
  PcNavDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
  PcNavDestination(icon: Icon(Icons.event_note_outlined), label: 'Visits'),
  PcNavDestination(icon: Icon(Icons.person_outline), label: 'Account'),
];

const _steps = 4;

/// `PcTopAppBar`, `PcNavigationBar` and `PcStepProgress`.
class NavigationSection extends StatefulWidget {
  /// Creates the section.
  const NavigationSection({super.key});

  @override
  State<NavigationSection> createState() => _NavigationSectionState();
}

class _NavigationSectionState extends State<NavigationSection> {
  int _tab = 0;
  int _step = 1;

  @override
  Widget build(BuildContext context) {
    return ShowcaseSection(
      title: 'Navigation',
      description:
          'App bar leading variants, the bottom navigation bar and step '
          'progress. Taps change local state only; no route changes.',
      specimens: [
        ShowcaseSpecimen(
          label: 'PcTopAppBar · leading',
          note: 'None, back, and close with a trailing action.',
          child: ShowcaseColumn(
            children: [
              const PcTopAppBar(
                title: 'No leading',
                leading: PcAppBarLeading.none,
              ),
              PcTopAppBar(
                title: 'Back',
                onLeadingPressed: () => showShowcaseFeedback(context, 'Back'),
              ),
              PcTopAppBar(
                title: 'Close',
                leading: PcAppBarLeading.close,
                onLeadingPressed: () => showShowcaseFeedback(context, 'Close'),
                trailing: PcIconButton(
                  icon: const Icon(Icons.notifications_none),
                  semanticLabel: 'Notifications',
                  onPressed: () =>
                      showShowcaseFeedback(context, 'Notifications'),
                ),
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcNavigationBar',
          note: 'Selected: ${_destinations[_tab].label}',
          child: PcNavigationBar(
            destinations: _destinations,
            selectedIndex: _tab,
            onSelected: (index) => setState(() => _tab = index),
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcStepProgress',
          child: ShowcaseColumn(
            children: [
              PcStepProgress(
                current: _step,
                total: _steps,
                caption: 'Step $_step of $_steps',
              ),
              ShowcaseWrap(
                children: [
                  PcButton(
                    label: 'Back',
                    variant: PcButtonVariant.outlined,
                    size: PcButtonSize.sm,
                    onPressed: _step > 0 ? () => setState(() => _step--) : null,
                  ),
                  PcButton(
                    label: 'Next',
                    variant: PcButtonVariant.tonal,
                    size: PcButtonSize.sm,
                    onPressed: _step < _steps
                        ? () => setState(() => _step++)
                        : null,
                  ),
                ],
              ),
              const PcStepProgress(
                current: 0,
                total: 3,
                caption: 'Not started',
              ),
              const PcStepProgress(current: 3, total: 3, caption: 'Complete'),
            ],
          ),
        ),
      ],
    );
  }
}
