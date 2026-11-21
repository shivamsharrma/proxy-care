import 'package:material_ui/material_ui.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/pc_theme.dart';
import '../../core/theme/tokens/pc_elevation.dart';
import '../../core/theme/tokens/pc_shape.dart';
import '../../core/theme/tokens/pc_sizes.dart';
import '../../core/theme/tokens/pc_spacing.dart';
import '../../core/theme/tokens/pc_typography.dart';
import 'pc_state_layer.dart';

/// How long a snackbar stays (Notification page: auto-dismiss 5s).
const Duration pcSnackBarDuration = Duration(seconds: 5);

/// Shows a snackbar confirming the user's own action (Notification page):
/// `color-neutral-800`, `radius-sm`, `shadow-1`, a 20px `color-primary-200`
/// check, 16px from the sides and floating above the navigation bar.
///
/// Never use it for errors that need action; use a banner or dialog.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showPcSnackBar(
  BuildContext context,
  String message,
) {
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: PcSnackBarContent(message: message),
      backgroundColor: const Color(0x00000000),
      elevation: 0,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(
        PcSpacing.space4,
        0,
        PcSpacing.space4,
        PcSpacing.space4,
      ),
      duration: pcSnackBarDuration,
    ),
  );
}

/// The visible body of a Proxy Care snackbar.
class PcSnackBarContent extends StatelessWidget {
  /// Creates snackbar content.
  const PcSnackBarContent({super.key, required this.message});

  /// Confirmation text.
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: PcSizes.touch),
        padding: const EdgeInsets.symmetric(
          vertical: PcSpacing.space4,
          horizontal: PcSpacing.space4,
        ),
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: const BorderRadius.all(Radius.circular(PcRadii.sm)),
          boxShadow: PcShadows.shadow1,
        ),
        child: Row(
          children: [
            Icon(
              Icons.check,
              size: PcSizes.iconMd,
              color: colors.inversePrimary,
            ),
            const SizedBox(width: PcSpacing.space3),
            Expanded(
              child: Text(
                message,
                style: PcTypeScale.bodyMd.copyWith(
                  color: colors.onInverseSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A heads-up notification for an event from the other party (Notification
/// page). Shown at the top, 12px from the sides and 8px from the top; the
/// whole banner is tappable.
class PcHeadsUpNotification extends StatelessWidget {
  /// Creates a heads-up notification.
  const PcHeadsUpNotification({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.body,
    this.actionLabel,
  });

  /// Insets from the screen edges where the notification is placed.
  static const EdgeInsets screenInsets = EdgeInsets.fromLTRB(
    PcSpacing.space3,
    PcSpacing.space2,
    PcSpacing.space3,
    0,
  );

  /// Icon in the 36px `color-primary-200` disc (a bell).
  final Widget icon;

  /// What happened.
  final String title;

  /// Detail line.
  final String? body;

  /// Trailing action text ("View", "Open").
  final String? actionLabel;

  /// Called when the notification is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    const shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(PcRadii.xl)),
    );
    return Semantics(
      liveRegion: true,
      button: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(PcRadii.xl)),
          boxShadow: PcShadows.shadow2,
        ),
        child: Material(
          color: colors.inverseSurface,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            overlayColor: pcStateLayer(colors.onInverseSurface),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: PcSpacing.space3,
                horizontal: PcSpacing.space4,
              ),
              child: Row(
                children: [
                  Container(
                    width: PcSizes.headsUpDisc,
                    height: PcSizes.headsUpDisc,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        size: PcSizes.iconMd,
                        color: colors.onPrimaryContainer,
                      ),
                      child: icon,
                    ),
                  ),
                  const SizedBox(width: PcSpacing.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: PcTypeScale.listTitle.copyWith(
                            color: colors.onPrimary,
                          ),
                        ),
                        if (body != null)
                          Text(
                            body!,
                            style: PcTypeScale.listMeta.copyWith(
                              color: colors.onInverseSurface,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(width: PcSpacing.space3),
                    Text(
                      actionLabel!,
                      style: PcTypeScale.buttonSm.copyWith(
                        color: colors.inversePrimary,
                      ),
                    ),
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

/// An inline explanation shown below its trigger (Notification page,
/// "Tooltip / info tip"): inverse surface, `radius-lg`, a 14/500 title, a
/// 14/20 body and a 40px close button.
class PcInfoTip extends StatelessWidget {
  /// Creates an info tip.
  const PcInfoTip({
    super.key,
    required this.title,
    required this.body,
    required this.onClose,
    this.closeLabel,
  });

  /// Tip title.
  final String title;

  /// Explanation.
  final String body;

  /// Called by the close button.
  final VoidCallback onClose;

  /// Screen-reader label of the close button. Defaults to the localized
  /// "Close".
  final String? closeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.pc.colors;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          PcSpacing.space4,
          PcSpacing.space3,
          PcSpacing.space2,
          PcSpacing.space2,
        ),
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: const BorderRadius.all(Radius.circular(PcRadii.lg)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PcTypeScale.buttonSm.copyWith(
                      color: colors.onPrimary,
                      letterSpacing: 0,
                    ),
                  ),
                  Text(
                    body,
                    style: PcTypeScale.bodyMd.copyWith(
                      color: colors.onInverseSurface,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              iconSize: PcSizes.iconMd,
              style: ButtonStyle(
                fixedSize: const WidgetStatePropertyAll(
                  Size.square(PcSizes.infoTipClose),
                ),
                minimumSize: const WidgetStatePropertyAll(
                  Size.square(PcSizes.infoTipClose),
                ),
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                foregroundColor: WidgetStatePropertyAll(
                  colors.onInverseSurface,
                ),
                overlayColor: pcStateLayer(colors.onInverseSurface),
                visualDensity: VisualDensity.standard,
              ),
              icon: Semantics(
                label: closeLabel ?? AppLocalizations.of(context).a11yClose,
                child: const ExcludeSemantics(child: Icon(Icons.close)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
