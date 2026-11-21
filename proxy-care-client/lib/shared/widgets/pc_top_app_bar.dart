import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/pc_theme.dart';
import '../../core/theme/system_ui.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';
import 'pc_icon_button.dart';

/// The leading control of a [PcTopAppBar] (usage rules, "Navigation").
enum PcAppBarLeading {
  /// No leading control: tab roots.
  none,

  /// Back arrow: any screen inside a flow.
  back,

  /// Close (×): the first screen of an abandonable flow, and status
  /// screens that leave the flow.
  close,
}

/// The 64px top app bar (TopAppBar page): `color-bg` background, a leading
/// 48px icon button and an `h3` single-line title. Sits under the status
/// bar, which it keeps transparent with dark icons.
class PcTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a top app bar.
  const PcTopAppBar({
    super.key,
    required this.title,
    this.leading = PcAppBarLeading.back,
    this.onLeadingPressed,
    this.trailing,
    this.backLabel,
    this.closeLabel,
  });

  /// Screen title.
  final String title;

  /// Back, close or nothing.
  final PcAppBarLeading leading;

  /// Called by the leading button. Defaults to `Navigator.maybePop`.
  final VoidCallback? onLeadingPressed;

  /// Up to one trailing icon button or status pill.
  final Widget? trailing;

  /// Screen-reader label of the back button. Defaults to the localized
  /// "Back".
  final String? backLabel;

  /// Screen-reader label of the close button. Defaults to the localized
  /// "Close".
  final String? closeLabel;

  @override
  Size get preferredSize => const Size.fromHeight(PcSizes.appBar);

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    final l10n = AppLocalizations.of(context);
    final onPressed =
        onLeadingPressed ?? () => Navigator.of(context).maybePop();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: PcSystemUi.light,
      child: ColoredBox(
        color: colors.bg,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: PcSizes.appBar,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PcSpacing.space1,
              ),
              child: Row(
                children: [
                  if (leading != PcAppBarLeading.none) ...[
                    PcIconButton(
                      icon: Icon(
                        leading == PcAppBarLeading.back
                            ? Icons.arrow_back
                            : Icons.close,
                      ),
                      semanticLabel: leading == PcAppBarLeading.back
                          ? backLabel ?? l10n.a11yBack
                          : closeLabel ?? l10n.a11yClose,
                      onPressed: onPressed,
                    ),
                    const SizedBox(width: PcSpacing.space1),
                  ] else
                    const SizedBox(width: PcSpacing.space5),
                  Expanded(
                    child: Semantics(
                      container: true,
                      header: true,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PcTypeScale.h3.copyWith(color: colors.text),
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: PcSpacing.space1),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
