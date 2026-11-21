import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_colors.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';
import 'pc_state_layer.dart';

/// A single card holding rows separated by hairlines (ListGroup page): the
/// pattern for payment requests, payment history and checklists. Inset
/// 16px from the screen edge.
class PcListGroup extends StatelessWidget {
  /// Creates a list group.
  const PcListGroup({super.key, required this.children});

  /// The rows, usually [PcListRow]s.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(PcRadii.xl)),
        side: BorderSide(color: colors.border, width: PcBorders.thin),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(color: colors.divider),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// A row in a [PcListGroup]: optional leading icon well, a single-line
/// `list-title`, a muted `list-meta` line ("Who · when"), and an optional
/// trailing amount, status and chevron.
class PcListRow extends StatelessWidget {
  /// Creates a list row.
  const PcListRow({
    super.key,
    required this.title,
    this.meta,
    this.leading,
    this.trailingAmount,
    this.trailingStatus,
    this.onTap,
  });

  /// Single-line title, truncated with an ellipsis.
  final String title;

  /// Meta line.
  final String? meta;

  /// Usually a [PcIconWell].
  final Widget? leading;

  /// Amount, already formatted.
  final String? trailingAmount;

  /// Status under the amount, usually a status badge.
  final Widget? trailingStatus;

  /// Makes the row a link and shows a trailing chevron.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: PcSizes.listRow),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          PcSpacing.space4,
          PcSpacing.space3,
          PcSpacing.space3,
          PcSpacing.space3,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: PcSpacing.space3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PcTypeScale.listTitle.copyWith(color: colors.text),
                  ),
                  if (meta != null)
                    Text(
                      meta!,
                      style: PcTypeScale.listMeta.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (trailingAmount != null || trailingStatus != null) ...[
              const SizedBox(width: PcSpacing.space3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (trailingAmount != null)
                    Text(
                      trailingAmount!,
                      style: PcTypeScale.listTitle.copyWith(
                        color: colors.text,
                      ),
                    ),
                  ?trailingStatus,
                ],
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(width: PcSpacing.space3),
              Icon(
                Icons.chevron_right,
                size: PcSizes.iconMd,
                color: colors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      overlayColor: pcStateLayer(colors.text),
      child: row,
    );
  }
}

/// A 40px circular icon well for list rows: [PcTone.warning] for pending
/// (`color-warning-100` + `color-warning-500` icon), [PcTone.success] for
/// done (`color-secondary-100` + `color-primary-500` icon).
class PcIconWell extends StatelessWidget {
  /// Creates an icon well.
  const PcIconWell({
    super.key,
    required this.icon,
    this.tone = PcTone.success,
  });

  /// The icon, sized 20px.
  final Widget icon;

  /// Pending ([PcTone.warning]) or done ([PcTone.success]); other tones
  /// use their container and accent.
  final PcTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    final (fill, iconColor) = switch (tone) {
      PcTone.success => (colors.secondaryContainer, colors.primary),
      _ => (colors.tone(tone).container, colors.tone(tone).accent),
    };
    return Container(
      width: PcSizes.iconWell,
      height: PcSizes.iconWell,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: IconTheme.merge(
        data: IconThemeData(size: PcSizes.iconMd, color: iconColor),
        child: icon,
      ),
    );
  }
}

/// A muted section header placed above a card group, with an optional
/// count (`section-label`, `c-section-label` in caretaker density).
class PcSectionLabel extends StatelessWidget {
  /// Creates a section label.
  const PcSectionLabel(this.text, {super.key, this.trailing});

  /// Header text.
  final String text;

  /// Optional count badge.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    return Semantics(
      container: true,
      header: true,
      child: Row(
        children: [
          Flexible(
            child: Text(
              text,
              style: pc.text.sectionLabel.copyWith(color: pc.colors.textMuted),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: PcSpacing.space2),
            trailing!,
          ],
        ],
      ),
    );
  }
}
