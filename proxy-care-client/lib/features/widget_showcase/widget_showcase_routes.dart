import 'package:go_router/go_router.dart';

import '../../core/config/env.dart';
import '../../core/router/route_access.dart';
import '../../core/router/route_definition.dart';
import '../../core/router/route_module.dart';
import 'presentation/widget_showcase_screen.dart';

/// Routes of the widget showcase, a development-only page listing every
/// design-system component.
///
/// The module is registered only when [isEnabled] (see
/// `enabledRouteModules` in `lib/app_routes.dart`, which lists the
/// development-only modules both apps add); otherwise the router
/// has no `/widget-showcase` route and the path shows "not found".
final class WidgetShowcaseRoutes extends RouteModule {
  /// Creates the module.
  const WidgetShowcaseRoutes();

  /// The `FEATURE_FLAGS` entry that turns the showcase on.
  static const featureFlag = 'widget_showcase';

  /// Whether [env] enables the showcase: the feature flag is on and the
  /// build is not a production build. Production never shows it, even if
  /// the flag is set by mistake.
  static bool isEnabled(Env env) =>
      !env.isProduction && env.isFeatureEnabled(featureFlag);

  /// `/widget-showcase`. Public: it shows no user data and calls no API,
  /// so it does not depend on the authentication state.
  static const home = RouteDefinition(
    name: 'widgetShowcase.home',
    path: '/widget-showcase',
    access: PublicAccess(),
  );

  @override
  String get name => 'widgetShowcase';

  @override
  List<RouteBase> buildRoutes(RouteBuildContext context) => [
    home.route(builder: (context, state) => const WidgetShowcaseScreen()),
  ];
}
