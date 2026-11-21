import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/theme/app_density.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_palette.dart';
import 'package:proxy_care_client/shared/widgets/pc_chip.dart';
import 'package:proxy_care_client/shared/widgets/pc_otp_input.dart';
import 'package:proxy_care_client/shared/widgets/pc_segmented_button.dart';
import 'package:proxy_care_client/shared/widgets/pc_selection_card.dart';
import 'package:proxy_care_client/shared/widgets/pc_switch.dart';
import 'package:proxy_care_client/shared/widgets/pc_text_field.dart';

import '../../helpers/pump_themed.dart';

InputDecoration _decoration(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!;

void main() {
  group('PcTextField', () {
    testWidgets('is 56 tall (family) and 60 tall (caretaker)', (
      tester,
    ) async {
      await pumpThemed(tester, const PcTextField(label: 'Mobile number'));
      expect(tester.getSize(find.byType(InputDecorator)).height, 56);

      await pumpThemed(
        tester,
        const PcTextField(label: 'Mobile number'),
        density: AppDensity.comfortable,
      );
      expect(tester.getSize(find.byType(InputDecorator)).height, 60);
    });

    testWidgets('outlined 1px, focused 2px primary, radius 4', (tester) async {
      await pumpThemed(tester, const PcTextField(label: 'Their full name'));
      final decoration = _decoration(tester);
      final enabled = decoration.enabledBorder! as OutlineInputBorder;
      final focused = decoration.focusedBorder! as OutlineInputBorder;
      expect(enabled.borderSide.width, 1);
      expect(enabled.borderSide.color, PcPalette.neutral500);
      expect(enabled.borderRadius, BorderRadius.circular(4));
      expect(focused.borderSide.width, 2);
      expect(focused.borderSide.color, PcPalette.primary500);
    });

    testWidgets('required label ends with an asterisk', (tester) async {
      await pumpThemed(
        tester,
        const PcTextField(label: 'Full name', isRequired: true),
      );
      expect(find.text('Full name *'), findsOneWidget);
    });

    testWidgets('error replaces the helper, with a 2px red border and icon', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const PcTextField(
          label: 'Mobile number',
          helper: 'We send the OTP here',
          error: 'Enter 10 digits, without 0 or +91',
        ),
      );
      final decoration = _decoration(tester);
      final error = decoration.errorBorder! as OutlineInputBorder;
      expect(error.borderSide.width, 2);
      expect(error.borderSide.color, PcPalette.error500);
      expect(find.text('Enter 10 digits, without 0 or +91'), findsOneWidget);
      expect(find.text('We send the OTP here'), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('textarea shows three rows', (tester) async {
      await pumpThemed(
        tester,
        const PcTextField(label: 'Notes', multiline: true),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 3);
      expect(field.maxLines, 3);
    });
  });

  group('PcOtpInput', () {
    testWidgets('takes digits only and reports completion', (tester) async {
      String? completed;
      await pumpThemed(
        tester,
        PcOtpInput(onCompleted: (code) => completed = code),
      );
      await tester.enterText(find.byType(TextField), '12a3456');
      await tester.pump();

      expect(completed, '123456');
      for (final digit in ['1', '2', '3', '4', '5', '6']) {
        expect(find.text(digit), findsOneWidget);
      }
    });

    testWidgets('labels each cell for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, const PcOtpInput());
      for (var i = 1; i <= PcOtpInput.length; i++) {
        expect(find.bySemanticsLabel('Digit $i of 6'), findsOneWidget);
      }
      handle.dispose();
    });

    testWidgets('error outlines every cell and shows the message', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const PcOtpInput(error: "That code didn't match. 2 tries left"),
      );
      expect(find.text("That code didn't match. 2 tries left"), findsOneWidget);
      final cells = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(Row),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).border != null,
          ),
        ),
      );
      expect(cells, hasLength(6));
      for (final cell in cells) {
        final border = (cell.decoration! as BoxDecoration).border! as Border;
        expect(border.top.color, PcPalette.error500);
        expect(border.top.width, 2);
      }
    });
  });

  group('chips', () {
    testWidgets('selected choice chip is tonal with a check', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        PcChoiceChip(label: 'Morning', selected: true, onTap: () {}),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(PcChoiceChip),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, PcPalette.secondary100);
      expect(find.byType(Icon), findsOneWidget);
      expect(tester.getSize(find.byType(PcChoiceChip)).height, 32);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Morning')),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('unselected chip is outlined with no check', (tester) async {
      await pumpThemed(
        tester,
        PcChoiceChip(label: 'Evening', selected: false, onTap: () {}),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(PcChoiceChip),
          matching: find.byType(Material),
        ),
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, PcPalette.neutral500);
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(8)));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('time-slot chip is 36 tall; disabled chips are 38%', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const PcChoiceChip(
          label: '10:00',
          selected: false,
          onTap: null,
          type: PcChipType.timeSlot,
        ),
      );
      expect(tester.getSize(find.byType(PcChoiceChip)).height, 36);
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        closeTo(0.38, 0.001),
      );
    });

    testWidgets('date cell is 60×76 and filled when selected', (tester) async {
      await pumpThemed(
        tester,
        PcDateCell(weekday: 'Mon', day: '14', selected: true, onTap: () {}),
      );
      expect(tester.getSize(find.byType(PcDateCell)), const Size(60, 76));
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(PcDateCell),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, PcPalette.primary500);
    });

    testWidgets('segmented button selects a segment', (tester) async {
      var selected = 'en';
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, setState) => PcSegmentedButton<String>(
            segments: const [
              PcSegment(value: 'en', label: 'English'),
              PcSegment(value: 'hi', label: 'हिन्दी'),
            ],
            selected: selected,
            onChanged: (value) => setState(() => selected = value),
          ),
        ),
      );
      expect(tester.getSize(find.byType(PcSegmentedButton<String>)).height, 48);
      await tester.tap(find.text('हिन्दी'));
      await tester.pump();
      expect(selected, 'hi');
      expect(find.byType(Icon), findsOneWidget);
    });
  });

  group('selection cards', () {
    testWidgets('selected radio card is 2px primary on primary-50', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        PcSelectionCard(
          title: 'Kamla Devi',
          meta: 'Mother · 72',
          selected: true,
          onTap: () {},
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(PcSelectionCard),
          matching: find.byType(Material),
        ),
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(material.color, PcPalette.primary50);
      expect(shape.side.color, PcPalette.primary500);
      expect(shape.side.width, 2);
      expect(shape.borderRadius, const BorderRadius.all(Radius.circular(16)));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Kamla Devi, Mother · 72')),
        isSemantics(
          isChecked: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('urgent selection uses the error tone', (tester) async {
      await pumpThemed(
        tester,
        PcSelectionCard(
          title: 'Emergency',
          selected: true,
          urgent: true,
          onTap: () {},
        ),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(PcSelectionCard),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, PcPalette.error50);
      expect(
        (material.shape! as RoundedRectangleBorder).side.color,
        PcPalette.error500,
      );
    });

    testWidgets('unselected card is at least 56 tall with a 1px border', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        PcSelectionCard(title: 'Can walk', selected: false, onTap: () {}),
      );
      expect(
        tester.getSize(find.byType(PcSelectionCard)).height,
        greaterThanOrEqualTo(56),
      );
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(PcSelectionCard),
          matching: find.byType(Material),
        ),
      );
      final side = (material.shape! as RoundedRectangleBorder).side;
      expect(side.color, PcPalette.neutral200);
      expect(side.width, 1);
    });

    testWidgets('checkbox tile toggles and shows the check badge', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var selected = false;
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, setState) => PcCheckboxTile(
            icon: const Icon(Icons.check),
            title: 'OPD visit',
            selected: selected,
            onTap: () => setState(() => selected = !selected),
          ),
        ),
      );
      expect(find.byType(Icon), findsOneWidget);
      await tester.tap(find.byType(PcCheckboxTile));
      await tester.pump();
      expect(selected, isTrue);
      expect(find.byType(Icon), findsNWidgets(2));
      expect(
        tester.getSemantics(find.bySemanticsLabel('OPD visit')),
        isSemantics(isChecked: true),
      );
      handle.dispose();
    });
  });

  group('PcSwitch', () {
    testWidgets('is 52×32 and toggles', (tester) async {
      final handle = tester.ensureSemantics();
      var value = false;
      await pumpThemed(
        tester,
        StatefulBuilder(
          builder: (context, setState) => PcSwitch(
            value: value,
            semanticLabel: 'You are online',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      );
      expect(tester.getSize(find.byType(PcSwitch)), const Size(52, 32));
      expect(
        tester.getSemantics(find.bySemanticsLabel('You are online')),
        isSemantics(hasToggledState: true, isToggled: false),
      );

      await tester.tap(find.byType(PcSwitch));
      await tester.pump();

      expect(value, isTrue);
      expect(find.byType(Icon), findsOneWidget, reason: 'check in thumb');
      expect(
        tester.getSemantics(find.bySemanticsLabel('You are online')),
        isSemantics(isToggled: true),
      );
      handle.dispose();
    });

    testWidgets('disabled switch is 38% and ignores taps', (tester) async {
      await pumpThemed(
        tester,
        const PcSwitch(value: true, onChanged: null),
      );
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        closeTo(0.38, 0.001),
      );
      await tester.tap(find.byType(PcSwitch));
    });
  });
}
