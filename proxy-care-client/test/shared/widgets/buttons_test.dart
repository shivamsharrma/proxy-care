import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/theme/app_density.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_palette.dart';
import 'package:proxy_care_client/shared/widgets/pc_button.dart';
import 'package:proxy_care_client/shared/widgets/pc_icon_button.dart';

import '../../helpers/pump_themed.dart';

ButtonStyle _style(WidgetTester tester) =>
    tester.widget<TextButton>(find.byType(TextButton)).style!;

Color? _resolve(
  WidgetStateProperty<Color?>? property, [
  Set<WidgetState> states = const {},
]) => property?.resolve(states);

void main() {
  group('PcButton', () {
    testWidgets('screen action is 56 (family) and 64 (caretaker) tall', (
      tester,
    ) async {
      await pumpThemed(tester, PcButton(label: 'Send OTP', onPressed: () {}));
      expect(tester.getSize(find.byType(TextButton)).height, 56);

      await pumpThemed(
        tester,
        PcButton(label: 'Send OTP', onPressed: () {}),
        density: AppDensity.comfortable,
      );
      expect(tester.getSize(find.byType(TextButton)).height, 64);
    });

    testWidgets('each size has its documented height', (tester) async {
      for (final size in PcButtonSize.values) {
        await pumpThemed(
          tester,
          PcButton(label: 'Go', onPressed: () {}, size: size),
        );
        final height = tester.getSize(find.byType(TextButton)).height;
        // Buttons under 48px keep a 48px touch target around them.
        expect(height, size.height < 48 ? 48 : size.height, reason: '$size');
      }
    });

    testWidgets('variants use the documented fill and label colors', (
      tester,
    ) async {
      final expected = {
        PcButtonVariant.filled: (PcPalette.primary500, PcPalette.neutral0),
        PcButtonVariant.tonal: (
          PcPalette.secondary100,
          PcPalette.secondary900,
        ),
        PcButtonVariant.outlined: (PcPalette.neutral0, PcPalette.primary500),
        PcButtonVariant.text: (null, PcPalette.primary500),
        PcButtonVariant.destructiveFilled: (
          PcPalette.error500,
          PcPalette.neutral0,
        ),
        PcButtonVariant.destructiveText: (null, PcPalette.error500),
      };
      for (final MapEntry(key: variant, value: (fill, label))
          in expected.entries) {
        await pumpThemed(
          tester,
          PcButton(label: 'Go', onPressed: () {}, variant: variant),
        );
        final style = _style(tester);
        expect(_resolve(style.backgroundColor), fill, reason: '$variant');
        expect(_resolve(style.foregroundColor), label, reason: '$variant');
      }
    });

    testWidgets('state layers are 8% on hover and 12% when pressed', (
      tester,
    ) async {
      await pumpThemed(tester, PcButton(label: 'Go', onPressed: () {}));
      final overlay = _style(tester).overlayColor;
      expect(
        _resolve(overlay, {WidgetState.hovered})!.a,
        closeTo(0.08, 0.005),
      );
      expect(
        _resolve(overlay, {WidgetState.pressed})!.a,
        closeTo(0.12, 0.005),
      );
    });

    testWidgets('text button label turns primary-600 on hover', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        PcButton(
          label: 'Keep booking',
          onPressed: () {},
          variant: PcButtonVariant.text,
        ),
      );
      expect(
        _resolve(_style(tester).foregroundColor, {WidgetState.hovered}),
        PcPalette.primary600,
      );
    });

    testWidgets('disabled uses the disabled colors and explains why', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const PcButton(
          label: 'Confirm',
          onPressed: null,
          disabledReason: '2 items left to tick',
        ),
      );
      final style = _style(tester);
      const disabled = {WidgetState.disabled};
      expect(_resolve(style.backgroundColor, disabled), PcPalette.neutral200);
      expect(_resolve(style.foregroundColor, disabled), PcPalette.neutral500);
      expect(find.text('2 items left to tick'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Confirm')),
        isSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('calls onPressed, but not while loading', (tester) async {
      var taps = 0;
      await pumpThemed(
        tester,
        PcButton(label: 'Pay ₹500', onPressed: () => taps++),
      );
      await tester.tap(find.byType(PcButton));
      expect(taps, 1);

      await pumpThemed(
        tester,
        PcButton(label: 'Pay ₹500', onPressed: () => taps++, loading: true),
      );
      await tester.tap(find.byType(PcButton));
      expect(taps, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('leading icon is sized by the button', (tester) async {
      await pumpThemed(
        tester,
        PcButton(
          label: 'Approve & pay ₹500',
          onPressed: () {},
          icon: const Icon(Icons.check),
        ),
      );
      expect(tester.getSize(find.byType(Icon)), const Size.square(20));
    });
  });

  group('PcIconButton', () {
    testWidgets('is a labelled 48px circle', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpThemed(
        tester,
        PcIconButton(
          icon: const Icon(Icons.arrow_back),
          semanticLabel: 'Back',
          onPressed: () => taps++,
        ),
      );
      expect(tester.getSize(find.byType(IconButton)), const Size.square(48));
      expect(tester.getSize(find.byType(Icon)), const Size.square(24));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Back')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      await tester.tap(find.byType(IconButton));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('info variant is 44px with a 20px icon', (tester) async {
      await pumpThemed(
        tester,
        PcIconButton(
          icon: const Icon(Icons.error_outline),
          semanticLabel: 'About this purpose',
          onPressed: () {},
          variant: PcIconButtonVariant.info,
        ),
      );
      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.style!.fixedSize!.resolve({}), const Size.square(44));
      // The padded tap target keeps 48px around the 44px button.
      expect(tester.getSize(find.byType(IconButton)), const Size.square(48));
      expect(tester.getSize(find.byType(Icon)), const Size.square(20));
    });
  });
}
