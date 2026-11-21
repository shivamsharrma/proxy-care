import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

const _loadingVariants = [
  PcButtonVariant.filled,
  PcButtonVariant.tonal,
  PcButtonVariant.outlined,
  PcButtonVariant.text,
];

/// The loading states the design system defines: the button spinner and
/// the progress sheet.
class LoadingSection extends StatefulWidget {
  /// Creates the section.
  const LoadingSection({super.key});

  @override
  State<LoadingSection> createState() => _LoadingSectionState();
}

class _LoadingSectionState extends State<LoadingSection> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return ShowcaseSection(
      title: 'Loading indicators',
      description:
          'A loading button keeps its width and ignores taps; long work '
          'uses the progress sheet. There is no standalone spinner or '
          'skeleton component.',
      specimens: [
        ShowcaseSpecimen(
          label: 'PcButton · loading',
          note: 'Switch loading off to see the labels.',
          child: ShowcaseColumn(
            children: [
              ShowcaseToggle(
                label: 'Loading',
                value: _loading,
                onChanged: (value) => setState(() => _loading = value),
              ),
              for (final variant in _loadingVariants)
                PcButton(
                  label: 'Continue',
                  variant: variant,
                  loading: _loading,
                  onPressed: () => showShowcaseFeedback(context, 'Continue'),
                ),
            ],
          ),
        ),
        const ShowcaseSpecimen(
          label: 'PcProgressSheet · content',
          note: 'Shown inline; Dialogs and sheets opens it as a modal.',
          child: PcProgressSheet(
            title: 'Confirming your payment',
            body: 'Please keep the app open.',
          ),
        ),
      ],
    );
  }
}
