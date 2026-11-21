import 'core/config/env.dart';
import 'core/router/route_module.dart';
import 'features/widget_showcase/widget_showcase_routes.dart';

/// Every feature's route module, in registration order.
///
/// This is the only list that names features: add one entry per feature
/// (for example `BookingsRoutes()` from
/// `features/bookings/bookings_routes.dart`). The routes themselves stay
/// in the feature. Empty until the first feature with screens exists.
const List<RouteModule> appRouteModules = [];

/// The route modules registered for [env]: [appRouteModules], plus the
/// development-only widget showcase when the build enables it (see
/// `WidgetShowcaseRoutes.isEnabled`).
List<RouteModule> enabledRouteModules(Env env) => [
  ...appRouteModules,
  if (WidgetShowcaseRoutes.isEnabled(env)) const WidgetShowcaseRoutes(),
];
