import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/app.dart';
import 'package:proxy_care_client/app_routes.dart';
import 'package:proxy_care_client/core/auth/authentication_session.dart';
import 'package:proxy_care_client/core/config/env.dart';
import 'package:proxy_care_client/core/di/auth_providers.dart';
import 'package:proxy_care_client/core/di/core_providers.dart';
import 'package:proxy_care_client/core/di/router_providers.dart';
import 'package:proxy_care_client/core/l10n/generated/app_localizations.dart';
import 'package:proxy_care_client/core/router/router_placeholder.dart';
import 'package:proxy_care_client/core/theme/app_density.dart';
import 'package:proxy_care_client/core/theme/app_theme.dart';
import 'package:proxy_care_client/core/theme/pc_theme.dart';
import 'package:proxy_care_client/features/widget_showcase/presentation/showcase_category.dart';
import 'package:proxy_care_client/features/widget_showcase/presentation/widget_showcase_screen.dart';
import 'package:proxy_care_client/features/widget_showcase/presentation/widgets/showcase_layout.dart';
import 'package:proxy_care_client/features/widget_showcase/widget_showcase_routes.dart';
import 'package:proxy_care_client/shared/widgets/design_system.dart';

import '../../fixtures/env_fixtures.dart';

const _flag = WidgetShowcaseRoutes.featureFlag;

Env _productionEnv({String featureFlags = ''}) => testEnv(
  appEnv: 'production',
  apiBaseUrl: 'https://api.example.test',
  supabaseUrl: 'https://project.supabase.co',
  supabasePublishableKey: 'sb_publishable_test',
  featureFlags: featureFlags,
);

/// Pumps the real app wired for [env] and returns its container.
Future<ProviderContainer> _pumpApp(WidgetTester tester, Env env) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        envProvider.overrideWithValue(env),
        authenticationSessionProvider.overrideWithValue(
          const UnconfiguredAuthenticationSession(),
        ),
        routeModulesProvider.overrideWithValue(enabledRouteModules(env)),
      ],
      child: const ProxyCareApp(),
    ),
  );
  await tester.pump();
  return ProviderScope.containerOf(tester.element(find.byType(ProxyCareApp)));
}

/// Pumps the showcase alone in a window of [size] logical pixels. The
/// showcase has always-spinning loading examples, so tests pump frames
/// instead of waiting for it to settle.
Future<void> _pumpShowcase(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildProxyCareTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const WidgetShowcaseScreen(),
    ),
  );
  await tester.pump();
}

Future<void> _selectCategory(
  WidgetTester tester,
  ShowcaseCategory category,
) async {
  await tester.tap(find.widgetWithText(PcChoiceChip, category.label));
  await tester.pump();
}

void main() {
  group('availability', () {
    test('needs the widget_showcase feature flag', () {
      expect(WidgetShowcaseRoutes.isEnabled(testEnv()), isFalse);
      expect(
        WidgetShowcaseRoutes.isEnabled(testEnv(featureFlags: _flag)),
        isTrue,
      );
    });

    test('is never enabled in production, even with the flag', () {
      expect(
        WidgetShowcaseRoutes.isEnabled(_productionEnv(featureFlags: _flag)),
        isFalse,
      );
      expect(
        enabledRouteModules(_productionEnv(featureFlags: _flag)),
        isNot(contains(isA<WidgetShowcaseRoutes>())),
      );
    });

    test('registers the module only when enabled', () {
      expect(
        enabledRouteModules(testEnv()).whereType<WidgetShowcaseRoutes>(),
        isEmpty,
      );
      final enabled = enabledRouteModules(testEnv(featureFlags: _flag));
      expect(enabled.whereType<WidgetShowcaseRoutes>(), hasLength(1));
    });

    test('config/env/showcase.json is valid and enables the showcase', () {
      final source = File('config/env/showcase.json').readAsStringSync();
      final json = jsonDecode(source) as Map<String, Object?>;
      String read(String key) => json[key]?.toString() ?? '';
      final env = Env.parse(
        appEnv: read(Env.appEnvKey),
        apiBaseUrl: read(Env.apiBaseUrlKey),
        appName: read(Env.appNameKey),
        enableLogging: read(Env.enableLoggingKey),
        featureFlags: read(Env.featureFlagsKey),
        supabaseUrl: read(Env.supabaseUrlKey),
        supabasePublishableKey: read(Env.supabasePublishableKeyKey),
        requireExplicitEnvironment: true,
      );

      expect(env.isProduction, isFalse);
      expect(WidgetShowcaseRoutes.isEnabled(env), isTrue);
    });
  });

  group('routing', () {
    testWidgets('opens /widget-showcase signed out when enabled', (
      tester,
    ) async {
      final container = await _pumpApp(tester, testEnv(featureFlags: _flag));

      container.read(routerProvider).go(WidgetShowcaseRoutes.home.fullPath);
      await tester.pump();
      await tester.pump();

      expect(WidgetShowcaseRoutes.home.fullPath, '/widget-showcase');
      expect(find.byType(WidgetShowcaseScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('/widget-showcase is not found when disabled', (
      tester,
    ) async {
      final container = await _pumpApp(tester, testEnv());

      container.read(routerProvider).go('/widget-showcase');
      await tester.pumpAndSettle();

      expect(find.byType(WidgetShowcaseScreen), findsNothing);
      final placeholder = tester.widget<RouterPlaceholder>(
        find.byType(RouterPlaceholder).last,
      );
      expect(placeholder.kind, RouterPlaceholderKind.notFound);
    });
  });

  group('showcase', () {
    for (final size in const [Size(360, 9000), Size(1440, 9000)]) {
      testWidgets('renders every category at ${size.width.round()}dp', (
        tester,
      ) async {
        await _pumpShowcase(tester, size);
        expect(tester.takeException(), isNull);

        for (final category in ShowcaseCategory.values) {
          await _selectCategory(tester, category);

          expect(find.byType(ShowcaseSection), findsOneWidget);
          expect(tester.takeException(), isNull, reason: category.label);
        }
      });
    }

    testWidgets('selection controls update in-memory state', (tester) async {
      await _pumpShowcase(tester, const Size(390, 9000));
      await _selectCategory(tester, ShowcaseCategory.selection);

      PcChoiceChip chip(String label) =>
          tester.widget(find.widgetWithText(PcChoiceChip, label));
      expect(chip('Afternoon').selected, isFalse);

      await tester.tap(find.widgetWithText(PcChoiceChip, 'Afternoon'));
      await tester.pump();

      expect(chip('Afternoon').selected, isTrue);
      expect(chip('Morning').selected, isFalse);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ShowcaseToggle, 'On'),
          matching: find.byType(PcSwitch),
        ),
      );
      await tester.pump();

      expect(find.widgetWithText(ShowcaseToggle, 'Off'), findsOneWidget);
    });

    testWidgets('previews the caretaker density locally', (tester) async {
      await _pumpShowcase(tester, const Size(390, 9000));
      await _selectCategory(tester, ShowcaseCategory.typography);

      await tester.tap(find.text('Caretaker'));
      await tester.pump();

      final section = tester.element(find.byType(ShowcaseSection));
      expect(section.pc.density, AppDensity.comfortable);
    });

    testWidgets('a dialog opens, closes and reports the choice', (
      tester,
    ) async {
      await _pumpShowcase(tester, const Size(390, 2000));
      await _selectCategory(tester, ShowcaseCategory.overlays);

      await tester.tap(find.text('Plain dialog'));
      await tester.pumpAndSettle();
      expect(find.text('Save these changes?'), findsOneWidget);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Save these changes?'), findsNothing);
      expect(find.text('Dismissed'), findsOneWidget);

      await tester.pump(pcSnackBarDuration);
      await tester.pumpAndSettle();
      expect(find.text('Dismissed'), findsNothing);
    });
  });
}
