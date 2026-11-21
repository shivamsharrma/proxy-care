import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';

/// Segmented step progress for multi-step flows (StepProgress page): one
/// 4px segment per step, 4px apart, done and current in
/// `color-primary-500`, upcoming in `color-neutral-300`, with an optional
/// caption 8px below ("Step 2 of 5 · Basic info").
///
/// Sits directly under the app bar with 24px insets.
class PcStepProgress extends StatelessWidget {
  /// Creates step progress.
  const PcStepProgress({
    super.key,
    required this.current,
    required this.total,
    this.caption,
    this.semanticLabel,
  }) : assert(total > 0, 'total must be positive'),
       assert(current >= 0 && current <= total, 'current out of range');

  /// The current step, 1-based. Steps up to and including it are filled.
  final int current;

  /// Number of steps.
  final int total;

  /// Visible caption ("Step 2 of 5 · Basic info").
  final String? caption;

  /// Screen-reader label for the bar. Defaults to the localized "Step n of
  /// N".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          image: true,
          label:
              semanticLabel ??
              AppLocalizations.of(context).a11yStepProgress(current, total),
          excludeSemantics: true,
          child: Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: PcSpacing.space1),
                Expanded(
                  child: Container(
                    height: PcSizes.stepBar,
                    decoration: BoxDecoration(
                      color: i < current
                          ? colors.primary
                          : colors.outlineVariant,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(PcRadii.xs),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: PcSpacing.space2),
          Text(
            caption!,
            style: pc.text.stepCaption.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}
