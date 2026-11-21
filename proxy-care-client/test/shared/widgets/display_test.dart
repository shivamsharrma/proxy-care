import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/theme/app_density.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_colors.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_palette.dart';
import 'package:proxy_care_client/shared/widgets/pc_avatar.dart';
import 'package:proxy_care_client/shared/widgets/pc_badge.dart';
import 'package:proxy_care_client/shared/widgets/pc_banner.dart';
import 'package:proxy_care_client/shared/widgets/pc_card.dart';
import 'package:proxy_care_client/shared/widgets/pc_empty_state.dart';
import 'package:proxy_care_client/shared/widgets/pc_list_group.dart';
import 'package:proxy_care_client/shared/widgets/pc_step_progress.dart';

import '../../helpers/pump_themed.dart';

BoxDecoration _boxOf(WidgetTester tester, Finder of) {
  return tester
      .widgetList<Container>(
        find.descendant(of: of, matching: find.byType(Container)),
      )
      .map((container) => container.decoration)
      .whereType<BoxDecoration>()
      .first;
}

void main() {
  group('cards', () {
    testWidgets('surface card is flat with a 1px border and 16px radius', (
      tester,
    ) async {
      await pumpThemed(tester, const PcCard(child: Text('Ongoing visit')));
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(PcCard),
          matching: find.byType(Material),
        ),
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(material.elevation, 0);
      expect(material.color, PcPalette.neutral0);
      expect(shape.side.color, PcPalette.neutral200);
      expect(shape.side.width, 1);
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(16)));
      expect(
        tester.getTopLeft(find.text('Ongoing visit')) -
            tester.getTopLeft(find.byType(PcCard)),
        const Offset(17, 17),
      );
    });

    testWidgets('attention card has a 2px warning border; content stays', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const PcCard(
          variant: PcCardVariant.attention,
          child: Text("Attach the hospital's bill"),
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(PcCard),
          matching: find.byType(Material),
        ),
      );
      final side = (material.shape! as RoundedRectangleBorder).side;
      expect(side.color, PcPalette.warning500);
      expect(side.width, 2);
      expect(
        tester.getTopLeft(find.text("Attach the hospital's bill")) -
            tester.getTopLeft(find.byType(PcCard)),
        const Offset(17, 17),
      );
    });

    testWidgets('stat tile shows a muted label over an amount', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const PcStatTile(label: 'This week', value: '₹2,625'),
      );
      final value = tester.widget<Text>(find.text('₹2,625'));
      expect(value.style?.fontSize, 22);
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(PcStatTile),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, PcPalette.neutral100);
    });

    testWidgets('expandable card opens from its summary row', (tester) async {
      await pumpThemed(
        tester,
        const PcExpandableCard(
          title: 'Already paid on this visit',
          trailing: '₹849',
          child: Text('OPD registration'),
        ),
      );
      expect(find.text('OPD registration'), findsNothing);
      await tester.tap(find.text('Already paid on this visit'));
      await tester.pump();
      expect(find.text('OPD registration'), findsOneWidget);
    });

    testWidgets('summary separates the total with a rule', (tester) async {
      await pumpThemed(
        tester,
        const PcSummary(
          rows: [
            PcSummaryRow(label: 'Hospital bills', value: '₹1,249'),
            PcSummaryRow(label: 'Advance', value: '−₹849'),
          ],
          totalLabel: 'You pay',
          totalValue: '₹400',
        ),
      );
      expect(find.byType(Divider), findsOneWidget);
      expect(tester.widget<Text>(find.text('₹400')).style?.fontSize, 26);
    });

    testWidgets('role card is a primary link', (tester) async {
      var taps = 0;
      await pumpThemed(
        tester,
        PcRoleCard(
          title: 'Book care for my family',
          subtitle: 'For a parent going to hospital',
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.byType(PcRoleCard));
      expect(taps, 1);
      expect(
        tester.widget<Text>(find.text('Book care for my family')).style?.color,
        PcPalette.neutral0,
      );
    });
  });

  group('list group', () {
    testWidgets('rows are at least 64 tall with dividers between them', (
      tester,
    ) async {
      var taps = 0;
      await pumpThemed(
        tester,
        PcListGroup(
          children: [
            PcListRow(
              title: 'OPD registration + consultation fee',
              meta: 'City Care Hospital · 10:18 AM',
              leading: const PcIconWell(
                icon: Icon(Icons.check),
                tone: PcTone.warning,
              ),
              trailingAmount: '₹500',
              onTap: () => taps++,
            ),
            const PcListRow(title: 'Pharmacy'),
          ],
        ),
      );
      expect(find.byType(Divider), findsOneWidget);
      final rows = tester.getSize(find.byType(PcListRow).first);
      expect(rows.height, greaterThanOrEqualTo(64));
      expect(
        find.descendant(
          of: find.byType(PcListRow).first,
          matching: find.byType(Icon),
        ),
        findsNWidgets(2),
        reason: 'well icon and chevron',
      );
      await tester.tap(find.text('₹500'));
      expect(taps, 1);
    });

    testWidgets('pending icon well uses the warning tone', (tester) async {
      await pumpThemed(
        tester,
        const PcIconWell(icon: Icon(Icons.check), tone: PcTone.warning),
      );
      final box = _boxOf(tester, find.byType(PcIconWell));
      expect(box.color, PcPalette.warning100);
      expect(tester.getSize(find.byType(PcIconWell)), const Size.square(40));
    });

    testWidgets('section label is a header', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const PcSectionLabel(
          'Pending payment requests',
          trailing: PcCountBadge(count: 2),
        ),
      );
      expect(
        tester.getSemantics(find.text('Pending payment requests')),
        isSemantics(isHeader: true),
      );
      handle.dispose();
    });
  });

  group('badges', () {
    testWidgets('status badge is 28 tall (32 caretaker) with a dot', (
      tester,
    ) async {
      const badge = PcStatusBadge(label: 'At hospital', tone: PcTone.warning);
      await pumpThemed(tester, badge);
      expect(tester.getSize(find.byType(PcStatusBadge)).height, 28);
      final box = _boxOf(tester, find.byType(PcStatusBadge));
      expect(box.color, PcPalette.warning100);
      expect(
        tester.widget<Text>(find.text('At hospital')).style?.color,
        PcPalette.warning900,
      );

      await pumpThemed(tester, badge, density: AppDensity.comfortable);
      expect(tester.getSize(find.byType(PcStatusBadge)).height, 32);
      expect(
        tester.widget<Text>(find.text('At hospital')).style?.fontSize,
        15,
      );
    });

    testWidgets('each tone uses its container and dot', (tester) async {
      for (final tone in PcTone.values) {
        await pumpThemed(tester, PcStatusBadge(label: 'Status', tone: tone));
        final boxes = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(PcStatusBadge),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .toList();
        final colors = PcColors.light.tone(tone);
        expect(boxes.first.color, colors.container, reason: '$tone');
        expect(boxes.last.color, colors.accent, reason: '$tone dot');
      }
    });

    testWidgets('live badges are announced', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const PcStatusBadge(label: 'Paid', tone: PcTone.success, live: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Paid')),
        isSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });

    testWidgets('tag is 24 and count badge is a 20px error pill', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PcTag(label: 'Fixed price'),
            PcCountBadge(count: 3),
          ],
        ),
      );
      expect(tester.getSize(find.byType(PcTag)).height, 24);
      expect(tester.getSize(find.byType(PcCountBadge)).height, 20);
      final pill = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(PcCountBadge),
              matching: find.byType(Container),
            ),
          )
          .first;
      expect((pill.decoration! as ShapeDecoration).color, PcPalette.error500);
    });

    testWidgets('tag and count badge hug their content in a column', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PcTag(label: 'Fixed'),
              PcCountBadge(count: 3),
            ],
          ),
        ),
      );

      expect(tester.getSize(find.byType(PcTag)).width, lessThan(100));
      expect(tester.getSize(find.byType(PcCountBadge)).width, 20);
    });
  });

  group('banners', () {
    testWidgets('info note: radius 12, padding 16, info colors', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const PcBanner.note(message: 'Only your family sees this.'),
      );
      final box = _boxOf(tester, find.byType(PcBanner));
      expect(box.color, PcPalette.neutral100);
      expect(box.borderRadius, const BorderRadius.all(Radius.circular(12)));
      expect(
        tester.widget<Text>(find.text('Only your family sees this.')).style,
        isA<TextStyle>().having((s) => s.color, 'color', PcPalette.neutral700),
      );
    });

    testWidgets('error status banner: radius 16 with title and body', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const PcBanner.status(
          title: "Couldn't verify this QR",
          body: 'No payment request was sent.',
          tone: PcTone.error,
          icon: Icon(Icons.close),
          live: true,
        ),
      );
      final box = _boxOf(tester, find.byType(PcBanner));
      expect(box.color, PcPalette.error100);
      expect(box.borderRadius, const BorderRadius.all(Radius.circular(16)));
      expect(
        tester.widget<Text>(find.text("Couldn't verify this QR")).style?.color,
        PcPalette.error900,
      );
      expect(
        tester.getSemantics(find.byType(PcBanner)),
        isSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });
  });

  group('avatar, empty and result states, step progress', () {
    testWidgets('avatar sizes are 36, 44 and 48 circles', (tester) async {
      for (final (size, diameter) in [
        (PcAvatarSize.sm, 36.0),
        (PcAvatarSize.md, 44.0),
        (PcAvatarSize.lg, 48.0),
      ]) {
        await pumpThemed(tester, PcAvatar(initials: 'KD', size: size));
        expect(
          tester.getSize(find.byType(PcAvatar)),
          Size.square(diameter),
        );
        final box = _boxOf(tester, find.byType(PcAvatar));
        expect(box.shape, BoxShape.circle);
        expect(box.color, PcPalette.secondary100);
      }
    });

    testWidgets('empty state paints a dashed border around one sentence', (
      tester,
    ) async {
      const message =
          "Nothing to pay right now. You'll be notified when a request "
          'comes in.';
      await pumpThemed(tester, const PcEmptyState(message: message));
      expect(find.text(message), findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(PcEmptyState),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = paint.painter! as PcDashedBorderPainter;
      expect(painter.color, PcPalette.neutral300);
      expect(painter.radius, 16);
    });

    testWidgets('result state shows a disc and an h1 title', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const PcResultState(
          icon: Icon(Icons.check),
          title: 'Visit completed',
          body: 'Kamla is home.',
        ),
      );
      expect(
        tester.widget<Text>(find.text('Visit completed')).style?.fontSize,
        28,
      );
      expect(
        tester.getSemantics(find.text('Visit completed')),
        isSemantics(isHeader: true),
      );
      expect(tester.getSize(find.byType(Icon)), const Size.square(36));
      handle.dispose();
    });

    testWidgets('step progress fills done steps and states the step', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const SizedBox(
          width: 342,
          child: PcStepProgress(
            current: 2,
            total: 5,
            caption: 'Step 2 of 5 · Basic info',
          ),
        ),
      );
      final segments = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(PcStepProgress),
              matching: find.byType(Container),
            ),
          )
          .map((c) => (c.decoration! as BoxDecoration).color)
          .toList();
      expect(segments, [
        PcPalette.primary500,
        PcPalette.primary500,
        PcPalette.neutral300,
        PcPalette.neutral300,
        PcPalette.neutral300,
      ]);
      expect(find.bySemanticsLabel('Step 2 of 5'), findsOneWidget);
      expect(find.text('Step 2 of 5 · Basic info'), findsOneWidget);
      handle.dispose();
    });
  });
}
