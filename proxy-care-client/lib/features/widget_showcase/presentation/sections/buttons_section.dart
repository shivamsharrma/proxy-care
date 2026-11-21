import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

/// `PcButton` (variants, sizes, states) and `PcIconButton` (variants,
/// disabled, muted).
class ButtonsSection extends StatefulWidget {
  /// Creates the section.
  const ButtonsSection({super.key});

  @override
  State<ButtonsSection> createState() => _ButtonsSectionState();
}

class _ButtonsSectionState extends State<ButtonsSection> {
  int _taps = 0;
  bool _enabled = true;
  bool _loading = false;
  Timer? _loadingTimer;

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _tap(String name) {
    setState(() => _taps++);
    showShowcaseFeedback(context, '$name pressed');
  }

  void _startLoading() {
    _loadingTimer?.cancel();
    setState(() => _loading = true);
    _loadingTimer = Timer(showcaseLoadingDuration, () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    VoidCallback? press(String name) => _enabled ? () => _tap(name) : null;

    return ShowcaseSection(
      title: 'Buttons',
      description:
          'PcButton in every variant and size, with its disabled, loading '
          'and icon states, and PcIconButton. Use the switch to disable the '
          'interactive examples.',
      specimens: [
        ShowcaseSpecimen(
          label: 'PcButton · variants',
          note: 'Default size follows the density. Taps so far: $_taps.',
          child: ShowcaseColumn(
            children: [
              ShowcaseToggle(
                label: 'Enabled',
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              for (final variant in PcButtonVariant.values)
                PcButton(
                  label: _variantLabel(variant),
                  variant: variant,
                  fullWidth: true,
                  onPressed: press(_variantLabel(variant)),
                ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcButton · sizes',
          note: 'Name and height in dp.',
          child: ShowcaseColumn(
            stretch: false,
            children: [
              for (final size in PcButtonSize.values)
                PcButton(
                  label: '${size.name} · ${size.height.round()}',
                  size: size,
                  onPressed: press('Size ${size.name}'),
                ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcButton · states',
          note: 'The first loading button runs for 2 seconds when tapped.',
          child: ShowcaseColumn(
            children: [
              PcButton(
                label: 'Pay ₹1,200',
                icon: const Icon(Icons.lock_outline),
                onPressed: press('Pay'),
              ),
              PcButton(
                label: _loading ? 'Saving' : 'Tap to load',
                variant: PcButtonVariant.tonal,
                loading: _loading,
                onPressed: _enabled ? _startLoading : null,
              ),
              PcButton(
                label: 'Always loading',
                variant: PcButtonVariant.outlined,
                loading: true,
                onPressed: () {},
              ),
              const PcButton(label: 'Disabled', onPressed: null),
              const PcButton(
                label: 'Disabled with a reason',
                onPressed: null,
                disabledReason: 'Choose a time slot to continue',
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcIconButton · variants',
          note: 'Top row enabled, bottom row disabled.',
          child: ShowcaseColumn(
            stretch: false,
            children: [
              ShowcaseWrap(
                children: [
                  for (final variant in PcIconButtonVariant.values)
                    PcIconButton(
                      icon: Icon(_iconFor(variant)),
                      semanticLabel: variant.name,
                      variant: variant,
                      onPressed: press('Icon button ${variant.name}'),
                    ),
                  PcIconButton(
                    icon: const Icon(Icons.more_vert),
                    semanticLabel: 'Muted',
                    muted: true,
                    onPressed: press('Muted icon button'),
                  ),
                ],
              ),
              ShowcaseWrap(
                children: [
                  for (final variant in PcIconButtonVariant.values)
                    PcIconButton(
                      icon: Icon(_iconFor(variant)),
                      semanticLabel: '${variant.name}, disabled',
                      variant: variant,
                      onPressed: null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _variantLabel(PcButtonVariant variant) => switch (variant) {
    PcButtonVariant.filled => 'Filled',
    PcButtonVariant.tonal => 'Tonal',
    PcButtonVariant.outlined => 'Outlined',
    PcButtonVariant.text => 'Text',
    PcButtonVariant.destructiveFilled => 'Destructive filled',
    PcButtonVariant.destructiveText => 'Destructive text',
  };

  static IconData _iconFor(PcIconButtonVariant variant) => switch (variant) {
    PcIconButtonVariant.standard => Icons.notifications_none,
    PcIconButtonVariant.filled => Icons.add,
    PcIconButtonVariant.tonal => Icons.call,
    PcIconButtonVariant.onMap => Icons.arrow_back,
    PcIconButtonVariant.info => Icons.info_outline,
  };
}
