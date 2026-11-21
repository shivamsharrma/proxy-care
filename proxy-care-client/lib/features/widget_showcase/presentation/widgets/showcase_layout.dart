import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/pc_theme.dart';
import '../../../../core/theme/tokens/pc_sizes.dart';
import '../../../../core/theme/tokens/pc_spacing.dart';
import '../../../../core/theme/tokens/pc_typography.dart';
import '../../../../shared/widgets/design_system.dart';

/// Widest the showcase content grows: three phone frames side by side, so
/// mobile-sized components are never stretched across a desktop window.
const double showcaseMaxWidth = PcSizes.frame * 3 + PcSpacing.space4 * 2;

/// How long simulated work (loading buttons, the progress sheet) lasts.
const Duration showcaseLoadingDuration = Duration(seconds: 2);

/// Confirms a showcase interaction with the design system's snackbar,
/// replacing any snackbar still on screen.
void showShowcaseFeedback(BuildContext context, String message) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  showPcSnackBar(context, message);
}

/// One showcase category: a heading, a short description and its
/// specimens, laid out in columns no wider than a phone frame.
class ShowcaseSection extends StatelessWidget {
  /// Creates a section.
  const ShowcaseSection({
    super.key,
    required this.title,
    required this.description,
    required this.specimens,
  });

  /// Category name.
  final String title;

  /// What the category holds and any variants the design system lacks.
  final String description;

  /// The examples, in reading order.
  final List<ShowcaseSpecimen> specimens;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: PcTypeScale.h2.copyWith(color: colors.text),
          ),
        ),
        const SizedBox(height: PcSpacing.space1),
        Text(
          description,
          style: PcTypeScale.bodyMd.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: PcSpacing.space4),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = math.min(constraints.maxWidth, PcSizes.frame);
            return Wrap(
              spacing: PcSpacing.space4,
              runSpacing: PcSpacing.space4,
              children: [
                for (final specimen in specimens)
                  SizedBox(
                    width: specimen.wide ? constraints.maxWidth : narrow,
                    child: specimen,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One example inside a section: a label, an optional note and the
/// component itself, on a card so examples stay visually separate.
class ShowcaseSpecimen extends StatelessWidget {
  /// Creates a specimen.
  const ShowcaseSpecimen({
    super.key,
    required this.label,
    required this.child,
    this.note,
    this.wide = false,
  });

  /// Component and variant name.
  final String label;

  /// How to interact with it, or what to look for.
  final String? note;

  /// Uses the full section width instead of one phone frame.
  final bool wide;

  /// The component under inspection.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final note = this.note;
    return PcCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PcSectionLabel(label),
          if (note != null) ...[
            const SizedBox(height: PcSpacing.space1),
            ShowcaseCaption(note),
          ],
          const SizedBox(height: PcSpacing.space3),
          child,
        ],
      ),
    );
  }
}

/// Muted supporting text: notes and live values.
class ShowcaseCaption extends StatelessWidget {
  /// Creates a caption.
  const ShowcaseCaption(this.text, {super.key});

  /// The text.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: PcTypeScale.bodySm.copyWith(color: context.pc.colors.textMuted),
    );
  }
}

/// Stacks [children] 8px apart.
class ShowcaseColumn extends StatelessWidget {
  /// Creates a column.
  const ShowcaseColumn({
    super.key,
    required this.children,
    this.stretch = true,
  });

  /// The stacked widgets.
  final List<Widget> children;

  /// Gives every child the full width; otherwise children keep their own
  /// width, aligned to the start.
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: stretch
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: PcSpacing.space2),
          children[i],
        ],
      ],
    );
  }
}

/// Wraps [children] 8px apart in both directions.
class ShowcaseWrap extends StatelessWidget {
  /// Creates a wrap.
  const ShowcaseWrap({super.key, required this.children});

  /// The wrapped widgets.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: PcSpacing.space2,
      runSpacing: PcSpacing.space2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

/// A labelled [PcSwitch]. A null [onChanged] shows the disabled state.
class ShowcaseToggle extends StatelessWidget {
  /// Creates a labelled switch.
  const ShowcaseToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  /// Visible label, also announced for the switch.
  final String label;

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value; null disables the switch.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: pc.text.bodyMd.copyWith(color: pc.colors.text),
          ),
        ),
        const SizedBox(width: PcSpacing.space3),
        PcSwitch(value: value, onChanged: onChanged, semanticLabel: label),
      ],
    );
  }
}
