import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/app_routes.dart';
import 'package:proxy_care_client/core/config/app_variant.dart';
import 'package:proxy_care_client/features/widget_showcase/widget_showcase_routes.dart';

import 'fixtures/env_fixtures.dart';

// Slice C0 (plan §4 "App variant"): each app variant registers only its own
// route modules. The "User app has no caretaker routes" (and reverse)
// assertion is added when OnboardingRoutes, FamilyRoutes and
// CaretakerKycRoutes exist; it targets `routeModulesFor`, the list the app
// registers.
void main() {
  final showcaseEnabled = testEnv(
    featureFlags: WidgetShowcaseRoutes.featureFlag,
  );
  final showcaseDisabled = testEnv();

  for (final variant in AppVariant.values) {
    group('${variant.name} app', () {
      test('never lists the development widget showcase as an app module', () {
        expect(
          appRouteModulesFor(variant).whereType<WidgetShowcaseRoutes>(),
          isEmpty,
        );
      });

      test('registers the widget showcase when the env enables it', () {
        expect(
          routeModulesFor(
            variant,
            showcaseEnabled,
          ).whereType<WidgetShowcaseRoutes>(),
          hasLength(1),
        );
      });

      test(
        'does not register the widget showcase when the env disables it',
        () {
          expect(
            routeModulesFor(
              variant,
              showcaseDisabled,
            ).whereType<WidgetShowcaseRoutes>(),
            isEmpty,
          );
        },
      );

      test('registers its own modules before the development modules', () {
        expect(routeModulesFor(variant, showcaseEnabled), [
          ...appRouteModulesFor(variant),
          ...enabledRouteModules(showcaseEnabled),
        ]);
      });
    });
  }
}
