import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_elevation.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';
import 'pc_button.dart';

/// Shows a [PcDialog] over the `color-scrim` and completes with true when
/// confirmed, false when dismissed, or null when closed another way.
Future<bool?> showPcDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String dismissLabel,
  String? body,
  Widget? icon,
  Widget? content,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: context.pc.colors.scrim,
    builder: (context) => PcDialog(
      title: title,
      body: body,
      icon: icon,
      content: content,
      destructive: destructive,
      confirmLabel: confirmLabel,
      onConfirm: () => Navigator.of(context).pop(true),
      dismissLabel: dismissLabel,
      onDismiss: () => Navigator.of(context).pop(false),
    ),
  );
}

/// A centered confirmation for decisions that cost money or can't be
/// undone (Dialog page).
///
/// `color-neutral-75` surface, `radius-3xl`, 24px padding and inset,
/// `shadow-3`. The title is a question in `h2`; actions are stacked
/// full-width 48px pills, confirm on top and the dismiss text button below.
/// In a [destructive] dialog the confirm button is red and focus starts on
/// the dismiss action.
class PcDialog extends StatelessWidget {
  /// Creates a dialog.
  const PcDialog({
    super.key,
    required this.title,
    required this.confirmLabel,
    required this.onConfirm,
    required this.dismissLabel,
    required this.onDismiss,
    this.body,
    this.icon,
    this.content,
    this.destructive = false,
  });

  /// A question ("Cancel this booking?").
  final String title;

  /// Key facts in `body-md` muted.
  final String? body;

  /// Icon in the optional 40px disc.
  final Widget? icon;

  /// Extra content, such as a key–value summary card.
  final Widget? content;

  /// Confirm label.
  final String confirmLabel;

  /// Called by the confirm button.
  final VoidCallback onConfirm;

  /// Dismiss label ("Keep booking").
  final String dismissLabel;

  /// Called by the dismiss button.
  final VoidCallback onDismiss;

  /// Uses the destructive confirm button and error icon disc.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors;
    final (discFill, discIcon) = destructive
        ? (colors.errorTone.container, colors.errorTone.accent)
        : (colors.secondaryContainer, colors.onSecondaryContainer);

    return Dialog(
      backgroundColor: const Color(0x00000000),
      elevation: 0,
      insetPadding: const EdgeInsets.all(PcSpacing.space6),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: title,
        child: Container(
          padding: const EdgeInsets.all(PcSpacing.space6),
          decoration: BoxDecoration(
            color: colors.dialogSurface,
            borderRadius: const BorderRadius.all(Radius.circular(PcRadii.xxxl)),
            boxShadow: PcShadows.shadow3,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (icon != null) ...[
                  Center(
                    child: Container(
                      width: PcSizes.dialogDisc,
                      height: PcSizes.dialogDisc,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: discFill,
                        shape: BoxShape.circle,
                      ),
                      child: IconTheme.merge(
                        data: IconThemeData(
                          size: PcSizes.iconMd,
                          color: discIcon,
                        ),
                        child: icon!,
                      ),
                    ),
                  ),
                  const SizedBox(height: PcSpacing.space4),
                ],
                Semantics(
                  container: true,
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: PcTypeScale.h2.copyWith(color: colors.text),
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: PcSpacing.space4),
                  Text(
                    body!,
                    textAlign: TextAlign.center,
                    style: pc.text.bodyMd.copyWith(color: colors.textMuted),
                  ),
                ],
                if (content != null) ...[
                  const SizedBox(height: PcSpacing.space4),
                  content!,
                ],
                const SizedBox(height: PcSpacing.space4),
                PcButton(
                  label: confirmLabel,
                  onPressed: onConfirm,
                  size: PcButtonSize.md,
                  fullWidth: true,
                  variant: destructive
                      ? PcButtonVariant.destructiveFilled
                      : PcButtonVariant.filled,
                ),
                const SizedBox(height: PcSpacing.space1),
                PcButton(
                  label: dismissLabel,
                  onPressed: onDismiss,
                  size: PcButtonSize.md,
                  fullWidth: true,
                  variant: PcButtonVariant.text,
                  autofocus: destructive,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
