import 'package:material_ui/material_ui.dart';

import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_colors.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';

/// Inline messages in the page flow (Banner page): a small [PcBanner.note]
/// for hints and a larger [PcBanner.status] when state changes.
///
/// Lead with what happened, then the consequence, then (if needed) an
/// inline [action]. Don't stack two banners of the same tone. Error states
/// use a full-width error-tone status banner; never blame the user.
class PcBanner extends StatelessWidget {
  /// A note: `radius-lg`, padding 12 16 (16 all round for info), a 20px
  /// icon top-aligned and `body-md` text.
  const PcBanner.note({
    super.key,
    required String message,
    this.tone = PcTone.info,
    this.icon,
    this.live = false,
  }) : body = message,
       title = null,
       action = null,
       trailing = null,
       _isNote = true;

  /// A status banner: `radius-xl`, padding 16, `title-sm` title, `body-md`
  /// body, an optional 44px icon disc in the tone accent with a white icon,
  /// an optional inline [action] and an optional [trailing] control
  /// (status card, e.g. "You are online" with a switch).
  const PcBanner.status({
    super.key,
    required String this.title,
    required this.body,
    required this.tone,
    this.icon,
    this.action,
    this.trailing,
    this.live = false,
  }) : _isNote = false;

  /// Status banner title: what happened.
  final String? title;

  /// Note text, or the status banner body: the consequence.
  final String body;

  /// Tone: info, warning (pending), success or error.
  final PcTone tone;

  /// Leading icon. In a status banner it sits in a 44px disc.
  final Widget? icon;

  /// Inline link under the body, in the tone accent.
  final Widget? action;

  /// Control at the end of a status banner.
  final Widget? trailing;

  /// Announces the banner politely when it appears after an action
  /// (`role="status"`).
  final bool live;

  final bool _isNote;

  @override
  Widget build(BuildContext context) {
    final pc = context.pc;
    final toneColors = pc.colors.tone(tone);
    final textStyle = pc.text.bodyMd.copyWith(color: toneColors.onContainer);

    final Widget content;
    if (_isNote) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            IconTheme.merge(
              data: IconThemeData(
                size: PcSizes.iconMd,
                color: toneColors.onContainer,
              ),
              child: icon!,
            ),
            const SizedBox(width: PcSpacing.space3),
          ],
          Expanded(child: Text(body, style: textStyle)),
        ],
      );
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: PcSizes.bannerDisc,
              height: PcSizes.bannerDisc,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: toneColors.accent,
                shape: BoxShape.circle,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  size: PcSizes.iconLg,
                  color: pc.colors.onPrimary,
                ),
                child: icon!,
              ),
            ),
            const SizedBox(width: PcSpacing.space3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title!,
                  style: PcTypeScale.titleSm.copyWith(
                    color: toneColors.onContainer,
                  ),
                ),
                Text(body, style: textStyle),
                if (action != null) ...[
                  const SizedBox(height: PcSpacing.space2),
                  action!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: PcSpacing.space3),
            trailing!,
          ],
        ],
      );
    }

    final padding = _isNote
        ? EdgeInsets.symmetric(
            vertical: tone == PcTone.info ? PcSpacing.space4 : PcSpacing.space3,
            horizontal: PcSpacing.space4,
          )
        : const EdgeInsets.all(PcSpacing.space4);

    return Semantics(
      liveRegion: live,
      container: true,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: toneColors.container,
          borderRadius: BorderRadius.all(
            Radius.circular(_isNote ? PcRadii.lg : PcRadii.xl),
          ),
        ),
        child: content,
      ),
    );
  }
}
