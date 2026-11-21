import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/tokens/pc_colors.dart';
import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

/// Notes and status banners (`PcBanner`), `PcStatusBadge`, `PcTag`,
/// `PcCountBadge`, `PcHeadsUpNotification`, `PcInfoTip` and the snackbar.
class FeedbackSection extends StatefulWidget {
  /// Creates the section.
  const FeedbackSection({super.key});

  @override
  State<FeedbackSection> createState() => _FeedbackSectionState();
}

class _FeedbackSectionState extends State<FeedbackSection> {
  bool _tipVisible = true;

  @override
  Widget build(BuildContext context) {
    return ShowcaseSection(
      title: 'Feedback',
      description:
          'Information, success, warning and error in every feedback '
          'component. Status always pairs color with an icon or label.',
      specimens: [
        ShowcaseSpecimen(
          label: 'PcBanner.note · tones',
          child: ShowcaseColumn(
            children: [
              for (final tone in PcTone.values)
                PcBanner.note(
                  message: '${_toneName(tone)} note: one short sentence.',
                  tone: tone,
                  icon: Icon(_toneIcon(tone)),
                ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcBanner.status',
          note: 'With an action, with a trailing control, and plain.',
          child: ShowcaseColumn(
            children: [
              PcBanner.status(
                title: 'Payment received',
                body: 'The receipt is ready.',
                tone: PcTone.success,
                icon: const Icon(Icons.check),
                action: PcButton(
                  label: 'View receipt',
                  variant: PcButtonVariant.text,
                  size: PcButtonSize.sm,
                  onPressed: () => showShowcaseFeedback(context, 'Receipt'),
                ),
              ),
              PcBanner.status(
                title: 'Running late',
                body: 'The new arrival time is 10:20 AM.',
                tone: PcTone.warning,
                icon: const Icon(Icons.schedule),
                trailing: PcIconButton(
                  icon: const Icon(Icons.call),
                  semanticLabel: 'Call',
                  variant: PcIconButtonVariant.tonal,
                  onPressed: () => showShowcaseFeedback(context, 'Call'),
                ),
              ),
              const PcBanner.status(
                title: 'Payment failed',
                body: 'Nothing was charged. Try again.',
                tone: PcTone.error,
                icon: Icon(Icons.error_outline),
              ),
              const PcBanner.status(
                title: 'On the way',
                body: 'Updates are announced to screen readers.',
                tone: PcTone.info,
                icon: Icon(Icons.info_outline),
                live: true,
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcStatusBadge · PcTag · PcCountBadge',
          child: ShowcaseColumn(
            stretch: false,
            children: [
              ShowcaseWrap(
                children: [
                  for (final tone in PcTone.values)
                    PcStatusBadge(label: _toneName(tone), tone: tone),
                ],
              ),
              ShowcaseWrap(
                children: [
                  for (final tone in PcTone.values)
                    PcTag(label: _toneName(tone).toUpperCase(), tone: tone),
                ],
              ),
              const ShowcaseWrap(
                children: [
                  PcCountBadge(count: 1),
                  PcCountBadge(count: 9),
                  PcCountBadge(count: 24),
                  PcCountBadge(count: 120),
                ],
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcHeadsUpNotification',
          note: 'Tap the notification.',
          child: ShowcaseColumn(
            children: [
              PcHeadsUpNotification(
                icon: const Icon(Icons.notifications_none),
                title: 'Your caretaker has arrived',
                body: 'Waiting at the main entrance',
                actionLabel: 'View',
                onTap: () => showShowcaseFeedback(context, 'Notification'),
              ),
              PcHeadsUpNotification(
                icon: const Icon(Icons.notifications_none),
                title: 'Title only',
                onTap: () => showShowcaseFeedback(context, 'Notification'),
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'PcInfoTip',
          note: 'Close the tip, then bring it back.',
          child: _tipVisible
              ? PcInfoTip(
                  title: 'Why we ask',
                  body: 'It helps the caretaker prepare for the visit.',
                  onClose: () => setState(() => _tipVisible = false),
                )
              : PcButton(
                  label: 'Show the tip again',
                  variant: PcButtonVariant.text,
                  size: PcButtonSize.sm,
                  onPressed: () => setState(() => _tipVisible = true),
                ),
        ),
        ShowcaseSpecimen(
          label: 'Snackbar · showPcSnackBar',
          note: 'Confirms an action the user took; auto-dismisses after 5s.',
          child: ShowcaseColumn(
            children: [
              const PcSnackBarContent(message: 'Static preview'),
              PcButton(
                label: 'Show snackbar',
                variant: PcButtonVariant.tonal,
                size: PcButtonSize.md,
                onPressed: () => showShowcaseFeedback(context, 'Saved'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _toneName(PcTone tone) => switch (tone) {
    PcTone.neutral => 'Neutral',
    PcTone.info => 'Information',
    PcTone.warning => 'Warning',
    PcTone.success => 'Success',
    PcTone.error => 'Error',
  };

  static IconData _toneIcon(PcTone tone) => switch (tone) {
    PcTone.neutral => Icons.info_outline,
    PcTone.info => Icons.info_outline,
    PcTone.warning => Icons.warning_amber_outlined,
    PcTone.success => Icons.check_circle_outline,
    PcTone.error => Icons.error_outline,
  };
}
