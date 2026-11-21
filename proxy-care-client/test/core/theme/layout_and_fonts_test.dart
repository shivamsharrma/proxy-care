import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/theme/font_licenses.dart';
import 'package:proxy_care_client/core/theme/pc_theme.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_breakpoints.dart';
import 'package:proxy_care_client/shared/widgets/pc_layout.dart';

import '../../helpers/pump_themed.dart';

void main() {
  group('provisional breakpoints', () {
    const breakpoints = PcBreakpoints.provisional;

    test('compact below 600dp, expanded from 600dp, content max 720dp', () {
      expect(breakpoints.classify(390), PcWindowClass.compact);
      expect(breakpoints.classify(599.9), PcWindowClass.compact);
      expect(breakpoints.classify(600), PcWindowClass.expanded);
      expect(breakpoints.classify(1024), PcWindowClass.expanded);
      expect(breakpoints.maxContentWidth, 720);
    });

    test('are configurable', () {
      const custom = PcBreakpoints(expandedMinWidth: 840);
      expect(custom.classify(700), PcWindowClass.compact);
    });

    testWidgets('the window class follows the window width', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      late PcWindowClass windowClass;
      await pumpThemed(
        tester,
        Builder(
          builder: (context) {
            windowClass = context.pcWindowClass;
            return const SizedBox();
          },
        ),
      );

      expect(windowClass, PcWindowClass.expanded);
    });

    testWidgets('constrained content is capped at 720dp only when wider', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await pumpThemed(
        tester,
        const PcConstrainedContent(child: SizedBox(width: double.infinity)),
      );
      expect(
        tester
            .getSize(
              find.descendant(
                of: find.byType(PcConstrainedContent),
                matching: find.byType(SizedBox),
              ),
            )
            .width,
        720,
      );

      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(
        tester.getSize(find.byType(PcConstrainedContent)).width,
        lessThan(390),
        reason: 'phones keep the full (padded) width',
      );
    });
  });

  group('bundled fonts', () {
    test('Noto Sans Devanagari 400, 500 and 700 are bundled with the OFL', () {
      for (final weight in ['Regular', 'Medium', 'Bold']) {
        expect(
          File(
            'assets/fonts/noto_sans_devanagari/NotoSansDevanagari-$weight.ttf',
          ).existsSync(),
          isTrue,
          reason: weight,
        );
      }
      final license = File(notoSansDevanagariLicenseAsset).readAsStringSync();
      expect(license, contains('SIL Open Font License, Version 1.1'));
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('family: Noto Sans Devanagari'));
      expect(pubspec, isNot(contains('Roboto')));
    });

    testWidgets('the font licence is registered', (tester) async {
      registerFontLicenses();

      final entries = await tester.runAsync(
        () => LicenseRegistry.licenses.toList(),
      );
      final packages = entries!.expand((entry) => entry.packages);
      expect(packages, contains('Noto Sans Devanagari'));
    });
  });
}
