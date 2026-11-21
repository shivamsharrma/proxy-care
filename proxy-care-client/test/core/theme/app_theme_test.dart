import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/app.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';
import 'package:proxy_care_client/core/theme/app_density.dart';
import 'package:proxy_care_client/core/theme/app_theme.dart';
import 'package:proxy_care_client/core/theme/pc_theme.dart';
import 'package:proxy_care_client/core/theme/theme_providers.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_colors.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_palette.dart';
import 'package:proxy_care_client/core/theme/tokens/pc_typography.dart';

import '../../fixtures/env_fixtures.dart';
import '../../helpers/provider_container.dart';

void main() {
  group('buildProxyCareTheme', () {
    final theme = buildProxyCareTheme();

    test('is a light Material 3 theme on the tinted background', () {
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, PcPalette.neutral50);
    });

    test('maps the color roles onto the ColorScheme', () {
      final scheme = theme.colorScheme;
      expect(scheme.primary, PcPalette.primary500);
      expect(scheme.onPrimary, PcPalette.neutral0);
      expect(scheme.primaryContainer, PcPalette.primary200);
      expect(scheme.onPrimaryContainer, PcPalette.primary900);
      expect(scheme.secondaryContainer, PcPalette.secondary100);
      expect(scheme.onSecondaryContainer, PcPalette.secondary900);
      expect(scheme.error, PcPalette.error500);
      expect(scheme.errorContainer, PcPalette.error100);
      expect(scheme.surface, PcPalette.neutral0);
      expect(scheme.onSurface, PcPalette.neutral900);
      expect(scheme.onSurfaceVariant, PcPalette.neutral700);
      expect(scheme.outline, PcPalette.neutral500);
      expect(scheme.outlineVariant, PcPalette.neutral300);
      expect(scheme.inverseSurface, PcPalette.neutral800);
      expect(scheme.surfaceTint.a, 0, reason: 'cards are flat');
    });

    test('uses the platform typeface with the Devanagari fallback', () {
      expect(PcTypeScale.bodyLg.fontFamily, isNull);
      expect(theme.textTheme.headlineMedium?.fontSize, PcTypeScale.h1.fontSize);
      expect(theme.textTheme.headlineMedium?.height, PcTypeScale.h1.height);
      expect(theme.textTheme.titleLarge?.fontSize, PcTypeScale.h3.fontSize);
      expect(
        theme.textTheme.bodyMedium?.fontFamilyFallback,
        PcFonts.fallback,
      );
    });

    test('keeps 48px targets and flat state layers', () {
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
      expect(theme.visualDensity, VisualDensity.standard);
      expect(theme.splashFactory, NoSplash.splashFactory);
    });

    test('styles sheets with the scrim and no shadow', () {
      expect(theme.bottomSheetTheme.modalBarrierColor, PcPalette.scrim);
      expect(theme.bottomSheetTheme.modalElevation, 0);
    });

    test('registers the PcTheme extension', () {
      final pc = theme.extension<PcTheme>();
      expect(pc, isNotNull);
      expect(pc!.density, AppDensity.standard);
      expect(pc.colors, same(PcColors.light));
    });
  });

  group('density', () {
    test('changes sizes and text roles, not colors', () {
      final standard = buildProxyCareTheme();
      final comfortable = buildProxyCareTheme(AppDensity.comfortable);

      expect(standard.navigationBarTheme.height, 80);
      expect(comfortable.navigationBarTheme.height, 84);
      expect(standard.textTheme.bodyLarge?.fontSize, 16);
      expect(comfortable.textTheme.bodyLarge?.fontSize, 18);
      expect(
        comfortable.textTheme.bodyLarge?.height,
        PcTypeScale.cBodyLg.height,
      );
      expect(comfortable.colorScheme, standard.colorScheme);

      final pc = comfortable.extension<PcTheme>()!;
      expect(pc.isComfortable, isTrue);
      expect(pc.metrics.screenActionHeight, 64);
    });

    test('PcTheme lerps discretely at the midpoint', () {
      final a = PcTheme.light(AppDensity.standard);
      final b = PcTheme.light(AppDensity.comfortable);
      expect(a.lerp(b, 0.4).density, AppDensity.standard);
      expect(a.lerp(b, 0.6).density, AppDensity.comfortable);
      expect(
        a.copyWith(density: AppDensity.comfortable).density,
        AppDensity.comfortable,
      );
    });
  });

  group('theme providers', () {
    test('default to the standard light theme', () {
      final container = createTestContainer();

      expect(container.read(appDensityProvider), AppDensity.standard);
      expect(container.read(appThemeModeProvider), ThemeMode.light);
      expect(
        container.read(appThemeProvider).extension<PcTheme>()!.density,
        AppDensity.standard,
      );
    });

    test('switching density rebuilds the theme', () {
      final container = createTestContainer();
      final before = container.read(appThemeProvider);

      container
          .read(appDensityProvider.notifier)
          .select(AppDensity.comfortable);
      final after = container.read(appThemeProvider);

      expect(after, isNot(same(before)));
      expect(after.navigationBarTheme.height, 84);
    });

    testWidgets('the app applies the theme and follows density changes', (
      tester,
    ) async {
      final container = createTestContainer(env: testEnv());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ProxyCareApp(),
        ),
      );

      MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app().theme?.extension<PcTheme>()?.density, AppDensity.standard);
      expect(app().themeMode, ThemeMode.light);
      expect(app().darkTheme, isNull);

      container
          .read(appDensityProvider.notifier)
          .select(AppDensity.comfortable);
      await tester.pump();

      expect(
        app().theme?.extension<PcTheme>()?.density,
        AppDensity.comfortable,
      );
      expect(container.read(envProvider).appName, 'Proxy Care Test');
    });
  });
}
