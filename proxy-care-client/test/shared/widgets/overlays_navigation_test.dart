import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/l10n/generated/app_localizations.dart';
import 'package:proxy_care_client/core/theme/app_density.dart';
import 'package:proxy_care_client/core/theme/app_theme.dart';
import 'package:proxy_care_client/core/theme/system_ui.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_palette.dart';
import 'package:proxy_care_client/shared/widgets/pc_bottom_sheet.dart';
import 'package:proxy_care_client/shared/widgets/pc_button.dart';
import 'package:proxy_care_client/shared/widgets/pc_dialog.dart';
import 'package:proxy_care_client/shared/widgets/pc_focus_ring.dart';
import 'package:proxy_care_client/shared/widgets/pc_layout.dart';
import 'package:proxy_care_client/shared/widgets/pc_navigation_bar.dart';
import 'package:proxy_care_client/shared/widgets/pc_notification.dart';
import 'package:proxy_care_client/shared/widgets/pc_top_app_bar.dart';

import '../../helpers/pump_themed.dart';

/// Pumps a scaffold whose body has a button that runs [onPressed].
Future<void> _pumpLauncher(
  WidgetTester tester,
  void Function(BuildContext context) onPressed, {
  PreferredSizeWidget? appBar,
  Widget? bottomNavigationBar,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildProxyCareTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: appBar,
        bottomNavigationBar: bottomNavigationBar,
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => onPressed(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('PcDialog', () {
    testWidgets('confirms and dismisses', (tester) async {
      bool? result;
      await _pumpLauncher(tester, (context) async {
        result = await showPcDialog(
          context,
          title: 'Cancel this booking?',
          body: 'You get ₹250 back.',
          confirmLabel: 'Cancel booking',
          dismissLabel: 'Keep booking',
          destructive: true,
        );
      });

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this booking?'), findsOneWidget);
      await tester.tap(find.text('Keep booking'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel booking'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('destructive: red confirm, focus on dismiss, scrim', (
      tester,
    ) async {
      await _pumpLauncher(tester, (context) {
        showPcDialog(
          context,
          title: 'Cancel this booking?',
          confirmLabel: 'Cancel booking',
          dismissLabel: 'Keep booking',
          destructive: true,
        );
      });
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final buttons = tester
          .widgetList<PcButton>(find.byType(PcButton))
          .toList();
      expect(buttons.first.variant, PcButtonVariant.destructiveFilled);
      expect(buttons.first.size, PcButtonSize.md);
      expect(buttons.last.variant, PcButtonVariant.text);
      expect(buttons.last.autofocus, isTrue);

      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.color, PcPalette.scrim);
      expect(
        tester.widget<Text>(find.text('Cancel this booking?')).style?.fontSize,
        24,
      );
    });
  });

  group('progress sheet', () {
    testWidgets('shows a 48px spinner and cannot be dismissed', (
      tester,
    ) async {
      await _pumpLauncher(tester, (context) {
        showPcProgressSheet(
          context,
          title: 'Opening secure payment',
          body: 'This takes a few seconds.',
        );
      });
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Opening secure payment'), findsOneWidget);
      final spinner = find.byType(CircularProgressIndicator);
      expect(tester.getSize(spinner), const Size.square(48));
      expect(
        tester.widget<CircularProgressIndicator>(spinner).strokeWidth,
        5,
      );

      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Opening secure payment'), findsOneWidget);
    });
  });

  group('notifications', () {
    testWidgets('snackbar uses the inverse surface and a check', (
      tester,
    ) async {
      await _pumpLauncher(
        tester,
        (context) => showPcSnackBar(context, 'Booking saved'),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Booking saved'), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.duration, const Duration(seconds: 5));
      final box = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(PcSnackBarContent),
              matching: find.byType(Container),
            ),
          )
          .first;
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, PcPalette.neutral800);
      expect(decoration.boxShadow, isNotEmpty);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('heads-up notification is tappable as a whole', (
      tester,
    ) async {
      var taps = 0;
      await pumpThemed(
        tester,
        PcHeadsUpNotification(
          icon: const Icon(Icons.check),
          title: 'Ravi reached the hospital',
          body: 'OPD registration started',
          actionLabel: 'View',
          onTap: () => taps++,
        ),
      );
      await tester.tap(find.text('OPD registration started'));
      expect(taps, 1);
      expect(
        tester.widget<Text>(find.text('View')).style?.color,
        PcPalette.primary200,
      );
    });

    testWidgets('info tip has a labelled close button', (tester) async {
      final handle = tester.ensureSemantics();
      var closed = false;
      await pumpThemed(
        tester,
        PcInfoTip(
          title: 'What is OPD?',
          body: 'An outpatient visit to a doctor.',
          onClose: () => closed = true,
        ),
      );
      await tester.tap(find.bySemanticsLabel('Close'));
      expect(closed, isTrue);
      handle.dispose();
    });
  });

  group('PcTopAppBar', () {
    testWidgets('is 64 tall with a labelled back button that pops', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildProxyCareTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    appBar: PcTopAppBar(title: 'Book a caretaker'),
                  ),
                ),
              ),
              child: const Text('Go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(PcTopAppBar)).height, 64);
      expect(
        tester.getSemantics(find.text('Book a caretaker')),
        isSemantics(isHeader: true),
      );
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).last,
      );
      expect(region.value, PcSystemUi.light);

      await tester.tap(find.bySemanticsLabel('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(PcTopAppBar), findsNothing);
      handle.dispose();
    });

    testWidgets('close variant uses the close label', (tester) async {
      final handle = tester.ensureSemantics();
      var closed = false;
      await _pumpLauncher(
        tester,
        (_) {},
        appBar: PcTopAppBar(
          title: 'Booking waiting',
          leading: PcAppBarLeading.close,
          onLeadingPressed: () => closed = true,
        ),
      );
      await tester.tap(find.bySemanticsLabel('Close'));
      expect(closed, isTrue);
      handle.dispose();
    });
  });

  group('PcNavigationBar', () {
    Widget bar(int selected) => PcNavigationBar(
      selectedIndex: selected,
      onSelected: (_) {},
      destinations: const [
        PcNavDestination(icon: Icon(Icons.check), label: 'Home'),
        PcNavDestination(icon: Icon(Icons.check), label: 'Visits'),
        PcNavDestination(icon: Icon(Icons.check), label: 'Payments'),
        PcNavDestination(icon: Icon(Icons.check), label: 'Family'),
      ],
    );

    testWidgets('is 80 tall with a bold active label', (tester) async {
      await _pumpLauncher(tester, (_) {}, bottomNavigationBar: bar(0));
      expect(tester.getSize(find.byType(NavigationBar)).height, 80);
      FontWeight? weightOf(String label) => tester
          .widget<RichText>(
            find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style
          ?.fontWeight;
      expect(weightOf('Home'), FontWeight.w700);
      expect(weightOf('Visits'), FontWeight.w500);
    });

    testWidgets('is 84 tall in caretaker density', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildProxyCareTheme(AppDensity.comfortable),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(bottomNavigationBar: bar(1)),
        ),
      );
      expect(tester.getSize(find.byType(NavigationBar)).height, 84);
    });
  });

  group('layout and focus', () {
    testWidgets('bottom action area pads 16/24/24 and stacks 8 apart', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildProxyCareTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PcBottomActionArea(
                children: [
                  PcButton(label: 'Continue', onPressed: () {}),
                  PcButton(
                    label: 'Save and finish later',
                    onPressed: () {},
                    variant: PcButtonVariant.text,
                    size: PcButtonSize.md,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final area = tester.getRect(find.byType(PcBottomActionArea));
      final primary = tester.getRect(find.byType(PcButton).first);
      final secondary = tester.getRect(find.byType(PcButton).last);
      expect(primary.left - area.left, 24);
      expect(primary.top - area.top, 16);
      expect(area.bottom - secondary.bottom, 24);
      expect(secondary.top - primary.bottom, 8);
    });

    testWidgets('keyboard focus draws a 2px primary ring', (tester) async {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(
        () => FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.automatic,
      );
      await pumpThemed(
        tester,
        PcButton(label: 'Continue', onPressed: () {}, autofocus: true),
      );
      await tester.pump();

      final ring = find.descendant(
        of: find.descendant(
          of: find.byType(PcFocusRing),
          matching: find.byType(IgnorePointer),
        ),
        matching: find.byType(DecoratedBox),
      );
      expect(ring, findsOneWidget);
      final border =
          (tester.widget<DecoratedBox>(ring).decoration as BoxDecoration)
                  .border!
              as Border;
      expect(border.top.width, 2);
      expect(border.top.color, PcPalette.primary500);
    });
  });
}
