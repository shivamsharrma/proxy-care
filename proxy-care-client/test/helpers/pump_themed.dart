import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/l10n/generated/app_localizations.dart';
import 'package:proxy_care_client/core/theme/app_density.dart';
import 'package:proxy_care_client/core/theme/app_theme.dart';

/// Pumps [child] inside a `MaterialApp` with the Proxy Care theme at
/// [density], centered on a scaffold.
Future<void> pumpThemed(
  WidgetTester tester,
  Widget child, {
  AppDensity density = AppDensity.standard,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildProxyCareTheme(density),
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
}

/// WCAG 2.x relative luminance of [color].
double relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG 2.x contrast ratio between two opaque colors.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
