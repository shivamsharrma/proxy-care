import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/design_system.dart';
import '../widgets/showcase_layout.dart';

/// `showPcDialog` (plain, with icon, destructive, with content) and
/// `showPcProgressSheet`.
class OverlaysSection extends StatelessWidget {
  /// Creates the section.
  const OverlaysSection({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowcaseSection(
      title: 'Dialogs and sheets',
      description:
          'Modal confirmations and the progress sheet. The snackbar shows '
          'which button closed a dialog.',
      specimens: [
        ShowcaseSpecimen(
          label: 'showPcDialog',
          note: 'Confirm, dismiss, or tap outside to close.',
          child: ShowcaseColumn(
            children: [
              PcButton(
                label: 'Plain dialog',
                variant: PcButtonVariant.tonal,
                size: PcButtonSize.md,
                onPressed: () => _openDialog(context, _DialogKind.plain),
              ),
              PcButton(
                label: 'Dialog with icon',
                variant: PcButtonVariant.tonal,
                size: PcButtonSize.md,
                onPressed: () => _openDialog(context, _DialogKind.icon),
              ),
              PcButton(
                label: 'Dialog with content',
                variant: PcButtonVariant.tonal,
                size: PcButtonSize.md,
                onPressed: () => _openDialog(context, _DialogKind.content),
              ),
              PcButton(
                label: 'Destructive dialog',
                variant: PcButtonVariant.destructiveText,
                size: PcButtonSize.md,
                onPressed: () => _openDialog(context, _DialogKind.destructive),
              ),
            ],
          ),
        ),
        ShowcaseSpecimen(
          label: 'showPcProgressSheet',
          note: 'Has no dismiss; this example closes itself after 2 seconds.',
          child: PcButton(
            label: 'Show progress sheet',
            variant: PcButtonVariant.tonal,
            size: PcButtonSize.md,
            onPressed: () => _showProgressSheet(context),
          ),
        ),
      ],
    );
  }
}

enum _DialogKind { plain, icon, content, destructive }

Future<void> _openDialog(BuildContext context, _DialogKind kind) async {
  final result = await switch (kind) {
    _DialogKind.plain => showPcDialog(
      context,
      title: 'Save these changes?',
      body: 'You can change them again later.',
      confirmLabel: 'Save',
      dismissLabel: 'Not now',
    ),
    _DialogKind.icon => showPcDialog(
      context,
      title: 'Turn on reminders?',
      body: 'We remind you a day before each visit.',
      icon: const Icon(Icons.notifications_none),
      confirmLabel: 'Turn on',
      dismissLabel: 'Not now',
    ),
    _DialogKind.content => showPcDialog(
      context,
      title: 'Pay ₹1,450?',
      content: const PcSummary(
        rows: [
          PcSummaryRow(label: 'Visit, 4 hours', value: '₹1,200'),
          PcSummaryRow(label: 'Pickup and drop', value: '₹250'),
        ],
        totalLabel: 'Total',
        totalValue: '₹1,450',
      ),
      confirmLabel: 'Pay ₹1,450',
      dismissLabel: 'Go back',
    ),
    _DialogKind.destructive => showPcDialog(
      context,
      title: 'Delete this note?',
      body: 'This cannot be undone.',
      icon: const Icon(Icons.delete_outline),
      destructive: true,
      confirmLabel: 'Delete',
      dismissLabel: 'Keep it',
    ),
  };
  if (!context.mounted) return;
  final message = switch (result) {
    true => 'Confirmed',
    false => 'Dismissed',
    null => 'Closed without a choice',
  };
  showShowcaseFeedback(context, message);
}

Future<void> _showProgressSheet(BuildContext context) async {
  final navigator = Navigator.of(context);
  final sheet = showPcProgressSheet(
    context,
    title: 'Saving your changes',
    body: 'This takes a moment.',
  );
  await Future<void>.delayed(showcaseLoadingDuration);
  navigator.pop();
  await sheet;
}
