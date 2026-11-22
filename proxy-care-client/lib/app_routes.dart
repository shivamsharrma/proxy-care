import 'core/config/app_variant.dart';
import 'core/config/env.dart';
import 'core/router/route_module.dart';
import 'features/widget_showcase/widget_showcase_routes.dart';

// These lists are the only place that names features: add one entry per
// feature (for example `BookingsRoutes()` from
// `features/bookings/bookings_routes.dart`) to the list of every app that
// shows it. The routes themselves stay in the feature. All empty until the
// first feature with screens exists.

/// Route modules both apps register.
const List<RouteModule> _sharedRouteModules = [];

/// Route modules only the User app registers.
const List<RouteModule> _userRouteModules = [];

/// Route modules only the Caretaker app registers.
const List<RouteModule> _caretakerRouteModules = [];

/// Every feature route module of the [variant] app, in registration order.
///
/// Each app registers only its own routes. This is a UX boundary, not a
/// security one: the server checks roles.
List<RouteModule> appRouteModulesFor(AppVariant variant) => [
  ..._sharedRouteModules,
  ...switch (variant) {
    AppVariant.user => _userRouteModules,
    AppVariant.caretaker => _caretakerRouteModules,
  },
];

/// The development-only route modules [env] enables: the widget showcase
/// when the build enables it (see `WidgetShowcaseRoutes.isEnabled`).
List<RouteModule> enabledRouteModules(Env env) => [
  if (WidgetShowcaseRoutes.isEnabled(env)) const WidgetShowcaseRoutes(),
];

/// Everything the [variant] app built with [env] registers:
/// [appRouteModulesFor] plus [enabledRouteModules].
List<RouteModule> routeModulesFor(AppVariant variant, Env env) => [
  ...appRouteModulesFor(variant),
  ...enabledRouteModules(env),
];
