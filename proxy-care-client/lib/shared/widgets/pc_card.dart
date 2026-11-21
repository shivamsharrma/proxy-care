import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';
import 'pc_focus_ring.dart';
import 'pc_state_layer.dart';

/// Card variants from the Card page. Cards are flat: a border, never a
/// shadow.
enum PcCardVariant {
  /// `color-surface`, 1px `color-border`.
  surface,

  /// `color-surface-container`, no border (stat tiles).
  container,

  /// `color-surface`, 2px `color-warning-500` border ("Attach the
  /// hospital's bill").
  attention,
}

/// A flat container with `radius-xl` corners and 16px padding. Cards inset
/// 16px from the screen edge and stack 12px apart; content inside is spaced
/// 12px apart.
///
/// With [onTap] the whole card is the link (cards with a single action).
class PcCard extends StatelessWidget {
  /// Creates a card.
  const PcCard({
    super.key,
    required this.child,
    this.variant = PcCardVariant.surface,
    this.onTap,
  });

  /// Card content.
  final Widget child;

  /// Fill and border.
  final PcCardVariant variant;

  /// Makes the whole card tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    final (fill, side) = switch (variant) {
      PcCardVariant.surface => (
        colors.surface,
        BorderSide(color: colors.border, width: PcBorders.thin),
      ),
      PcCardVariant.container => (colors.surfaceContainer, BorderSide.none),
      PcCardVariant.attention => (
        colors.surface,
        BorderSide(color: colors.warningTone.accent, width: PcBorders.thick),
      ),
    };
    return pcCardSurface(
      context,
      fill: fill,
      side: side,
      onTap: onTap,
      child: child,
    );
  }
}

/// Paints a `radius-xl` card surface with 16px padding.
///
/// The spec's CSS puts the border outside the padding and drops the padding
/// by 1px when the border goes to 2px, so content always sits 17px in. A
/// Flutter shape paints its border inside the box, so the padding here is
/// the 16px plus the 1px base border, whatever the border width.
Widget pcCardSurface(
  BuildContext context, {
  required Color fill,
  required BorderSide side,
  required Widget child,
  VoidCallback? onTap,
}) {
  final shape = RoundedRectangleBorder(
    borderRadius: const BorderRadius.all(Radius.circular(PcRadii.xl)),
    side: side,
  );
  final padded = Padding(
    padding: const EdgeInsets.all(PcSpacing.space4 + PcBorders.thin),
    child: child,
  );
  final surface = Material(
    color: fill,
    shape: shape,
    clipBehavior: Clip.antiAlias,
    child: onTap == null
        ? padded
        : InkWell(
            onTap: onTap,
            customBorder: shape,
            overlayColor: pcStateLayer(context.pc.colors.text),
            child: padded,
          ),
  );
  if (onTap == null) return surface;
  return PcFocusRing(borderRadius: PcRadii.xl, child: surface);
}

/// A stat tile: `color-surface-container`, label `body-md` muted above a
/// value in `amount-md` ("This week ₹2,625"). Pair tiles in a 2-column grid
/// with a 12px gap.
class PcStatTile extends StatelessWidget {
  /// Creates a stat tile.
  const PcStatTile({super.key, required this.label, required this.value});

  /// What the number is.
  final String label;

  /// The number, already formatted.
  final String value;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    return PcCard(
      variant: PcCardVariant.container,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: pc.text.bodyMd.copyWith(color: pc.colors.textMuted),
          ),
          Text(
            value,
            style: PcTypeScale.amountMd.copyWith(color: pc.colors.text),
          ),
        ],
      ),
    );
  }
}

/// A full-width role card that is a link (Card page, "Role card"). The
/// primary role uses `color-primary-500` with a white `title-md` title and
/// a `color-primary-100` subtitle; the secondary role uses
/// `color-surface-container-high`.
class PcRoleCard extends StatelessWidget {
  /// Creates a role card.
  const PcRoleCard({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.primary = true,
  });

  /// Role name.
  final String title;

  /// Supporting line.
  final String? subtitle;

  /// Called on tap.
  final VoidCallback? onTap;

  /// Primary or secondary role styling.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors;
    final titleColor = primary ? colors.onPrimary : colors.text;
    final subtitleColor = primary ? colors.onPrimaryMuted : colors.textMuted;
    return Semantics(
      container: true,
      button: true,
      child: pcCardSurface(
        context,
        fill: primary ? colors.primary : colors.surfaceContainerHigh,
        side: BorderSide.none,
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PcTypeScale.titleMd.copyWith(color: titleColor),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: pc.text.bodyMd.copyWith(color: subtitleColor),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: PcSizes.iconMd,
              color: titleColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// A surface card whose body opens from a summary row: title 16/500 with
/// the total right-aligned ("Already paid on this visit").
class PcExpandableCard extends StatefulWidget {
  /// Creates an expandable card.
  const PcExpandableCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.initiallyExpanded = false,
  });

  /// Summary title.
  final String title;

  /// Right-aligned summary value (a total).
  final String? trailing;

  /// Body shown when expanded.
  final Widget child;

  /// Whether the card starts open.
  final bool initiallyExpanded;

  @override
  State<PcExpandableCard> createState() => _PcExpandableCardState();
}

class _PcExpandableCardState extends State<PcExpandableCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    final summaryStyle = PcTypeScale.titleSm.copyWith(color: colors.text);
    return PcCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            button: true,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              overlayColor: pcStateLayer(colors.text),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: PcSizes.touch),
                child: Row(
                  children: [
                    Expanded(child: Text(widget.title, style: summaryStyle)),
                    if (widget.trailing != null) ...[
                      Text(widget.trailing!, style: summaryStyle),
                      const SizedBox(width: PcSpacing.space2),
                    ],
                    RotatedBox(
                      quarterTurns: _expanded ? 2 : 0,
                      child: Icon(
                        Icons.expand_more,
                        size: PcSizes.iconMd,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: PcSpacing.space3),
            widget.child,
          ],
        ],
      ),
    );
  }
}

/// One line of a [PcSummary].
final class PcSummaryRow {
  /// Creates a summary row.
  const PcSummaryRow({required this.label, required this.value});

  /// Left label (`color-text-muted`).
  final String label;

  /// Right value.
  final String value;
}

/// A key–value summary (Card page): labels muted on the left, values on
/// the right, 8px apart, then a 1px `color-border` rule and the total in
/// `amount-lg`. Used in final bills and the cancel dialog.
class PcSummary extends StatelessWidget {
  /// Creates a summary.
  const PcSummary({
    super.key,
    required this.rows,
    this.totalLabel,
    this.totalValue,
  });

  /// The lines above the total.
  final List<PcSummaryRow> rows;

  /// Total label; shown with [totalValue].
  final String? totalLabel;

  /// Total amount, already formatted.
  final String? totalValue;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final colors = pc.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: PcSpacing.space2),
          Row(
            children: [
              Expanded(
                child: Text(
                  rows[i].label,
                  style: pc.text.bodyMd.copyWith(color: colors.textMuted),
                ),
              ),
              Text(
                rows[i].value,
                style: pc.text.bodyMd.copyWith(color: colors.text),
              ),
            ],
          ),
        ],
        if (totalLabel != null && totalValue != null) ...[
          const SizedBox(height: PcSpacing.space2),
          Divider(color: colors.border),
          const SizedBox(height: PcSpacing.space2),
          Row(
            children: [
              Expanded(
                child: Text(
                  totalLabel!,
                  style: PcTypeScale.titleSm.copyWith(color: colors.text),
                ),
              ),
              Text(
                totalValue!,
                style: PcTypeScale.amountLg.copyWith(color: colors.text),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
