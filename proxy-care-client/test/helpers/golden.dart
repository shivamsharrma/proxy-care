import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/theme/app_density.dart';
import 'package:proxy_care_client/core/theme/app_theme.dart';

/// Golden tests for design-system components. Conventions (TESTING.md):
///
/// - One golden per component family, a column of its documented variants
///   and states, on the Proxy Care theme at [density].
/// - Text renders in the test font (Ahem blocks): goldens check colors,
///   shapes, borders, spacing and sizes, not glyphs. Typography is checked
///   by unit tests against the type scale instead.
/// - Images live next to the test in `goldens/<name>.png` and are blessed
///   only by the "Bless goldens" workflow (Linux, pinned Flutter), then
///   reviewed by eye against the design system before merging.
/// - Goldens are skipped on other operating systems, whose rendering
///   differs slightly.
void goldenTest(
  String description, {
  required String name,
  required List<Widget> children,
  AppDensity density = AppDensity.standard,
  double width = 360,
}) {
  testWidgets(
    description,
    (tester) async {
      tester.view
        ..physicalSize = Size(width, 1000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildProxyCareTheme(density),
          themeAnimationDuration: Duration.zero,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: const ValueKey('golden'),
                child: Builder(
                  builder: (context) => Container(
                    width: width,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 12,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      // One frame: loading spinners never settle, and themes don't animate.
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('golden')),
        matchesGoldenFile('goldens/$name.png'),
      );
    },
    tags: const ['golden'],
    skip: !Platform.isLinux,
  );
}
