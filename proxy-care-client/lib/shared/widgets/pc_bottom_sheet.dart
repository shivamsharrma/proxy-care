import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';

/// Shows the modal progress sheet ("Opening secure payment") over the
/// `color-scrim`. It has no dismiss: the caller closes it with
/// `Navigator.pop` when the work finishes.
Future<void> showPcProgressSheet(
  BuildContext context, {
  required String title,
  String? body,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    barrierColor: context.pc.colors.scrim,
    backgroundColor: context.pc.colors.surface,
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(PcRadii.xxxl)),
    ),
    builder: (context) => PopScope(
      canPop: false,
      child: PcProgressSheet(title: title, body: body),
    ),
  );
}

/// Content of the modal progress sheet (BottomSheet page): padding 28 24 40,
/// a centered 48px spinner (5px `color-secondary-100` ring, `color-primary-500`
/// arc), a 20/28 500 title and a 15/22 muted body. Announced politely.
class PcProgressSheet extends StatelessWidget {
  /// Creates progress sheet content.
  const PcProgressSheet({super.key, required this.title, this.body});

  /// What is happening ("Opening secure payment").
  final String title;

  /// Plain-language detail.
  final String? body;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    return Semantics(
      liveRegion: true,
      container: true,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            PcSpacing.space6,
            PcSpacing.space7,
            PcSpacing.space6,
            PcSpacing.space10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: PcSizes.spinner,
                child: CircularProgressIndicator(
                  strokeWidth: PcSizes.spinnerStroke,
                  color: colors.primary,
                  backgroundColor: colors.secondaryContainer,
                ),
              ),
              const SizedBox(height: PcSpacing.space6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: PcTypeScale.sheetTitle.copyWith(color: colors.text),
              ),
              if (body != null) ...[
                const SizedBox(height: PcSpacing.space2),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: PcTypeScale.cBodyMd.copyWith(color: colors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
