import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';

/// A dashed `radius-xl` card in place of missing content (EmptyState page):
/// 1px dashed `color-neutral-300`, no fill, padding 16 20, one sentence
/// saying what's missing and where it will come from. No illustration and
/// no button unless there's an obvious next step.
class PcEmptyState extends StatelessWidget {
  /// Creates an empty state.
  const PcEmptyState({super.key, required this.message, this.icon});

  /// "Nothing to pay right now. You'll be notified when a request comes in."
  final String message;

  /// Optional 32px outline icon (stroke 1.5) in `color-outline`.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors;
    return CustomPaint(
      painter: PcDashedBorderPainter(
        color: colors.outlineVariant,
        radius: PcRadii.xl,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: PcSpacing.space4,
          horizontal: PcSpacing.space5,
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              IconTheme.merge(
                data: IconThemeData(
                  size: PcSizes.iconEmptyState,
                  color: colors.outline,
                ),
                child: icon!,
              ),
              const SizedBox(width: PcSpacing.space3),
            ],
            Expanded(
              child: Text(
                message,
                style: pc.text.emptyState.copyWith(color: colors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle border.
class PcDashedBorderPainter extends CustomPainter {
  /// Creates a dashed border painter.
  const PcDashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = PcBorders.thin,
    this.dash = PcSpacing.space1,
    this.gap = PcSpacing.space1,
  });

  /// Dash color.
  final Color color;

  /// Corner radius.
  final double radius;

  /// Line width.
  final double strokeWidth;

  /// Dash length.
  final double dash;

  /// Gap between dashes.
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final source = Path()..addRRect(rect);
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        dashed.addPath(metric.extractPath(d, d + dash), Offset.zero);
      }
    }
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(PcDashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}

/// Result disc variants (EmptyState page, "Result").
enum PcResultTone {
  /// `color-primary-200` disc with a `color-primary-900` icon: raised,
  /// received.
  received,

  /// `color-primary-500` disc with a white icon: completed.
  completed,
}

/// A centered success result (EmptyState page and usage rules): a 72 or
/// 80px disc with a check or shield, an `h1` title, one line of `body-lg`
/// muted, then a single primary [action] to the next useful place.
class PcResultState extends StatelessWidget {
  /// Creates a result state.
  const PcResultState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
    this.tone = PcResultTone.completed,
    this.large = false,
  });

  /// Check or shield icon in the disc.
  final Widget icon;

  /// "Visit completed".
  final String title;

  /// One line of supporting text.
  final String? body;

  /// The single primary button.
  final Widget? action;

  /// Disc colors.
  final PcResultTone tone;

  /// 80px disc with a 44px icon instead of 72px with 36px.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors;
    final (fill, iconColor) = switch (tone) {
      PcResultTone.received => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
      PcResultTone.completed => (colors.primary, colors.onPrimary),
    };
    final disc = large ? PcSizes.resultDiscLg : PcSizes.resultDiscSm;
    final iconSize = large ? PcSizes.iconResultLg : PcSizes.iconResultSm;

    return Padding(
      padding: const EdgeInsets.only(top: PcSpacing.space10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: disc,
              height: disc,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: IconTheme.merge(
                data: IconThemeData(size: iconSize, color: iconColor),
                child: icon,
              ),
            ),
          ),
          const SizedBox(height: PcSpacing.space6),
          Semantics(
            container: true,
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: PcTypeScale.h1.copyWith(color: colors.text),
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: PcSpacing.space2),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: pc.text.bodyLg.copyWith(color: colors.textMuted),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: PcSpacing.space8),
            action!,
          ],
        ],
      ),
    );
  }
}
