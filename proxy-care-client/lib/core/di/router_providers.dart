import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../router/notification_navigator.dart';
import '../router/route_guards.dart';
import '../router/route_module.dart';
import '../router/router_options.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

// Routing providers. The app has exactly one router (`routerProvider`);
// features contribute routes through `routeModulesProvider`, which
// `lib/app_routes.dart` overrides at start-up.

/// Every feature's route module. Empty by default; `main.dart` overrides it
/// with `enabledRouteModules(env)` from `lib/app_routes.dart`, and tests
/// override it with test modules.
final routeModulesProvider = Provider<List<RouteModule>>((ref) => const []);

/// App-wide router settings (redirect destinations, deep links, fallbacks).
final routerOptionsProvider = Provider<RouterOptions>(
  (ref) => const RouterOptions(),
);

/// Feature availability for `AuthenticatedAccess.feature`: the
/// `FEATURE_FLAGS` build setting.
final featureAccessPolicyProvider = Provider<FeatureAccessPolicy>(
  (ref) => FeatureFlagAccessPolicy(ref.watch(envProvider).featureFlags),
);

/// Route access decisions, usable outside the router (for example to hide
/// an entry the user may not open).
final routeAuthorizerProvider = Provider<RouteAuthorizer>(
  (ref) => RouteAuthorizer(
    authorization: ref.watch(authorizationServiceProvider),
    features: ref.watch(featureAccessPolicyProvider),
  ),
);

/// The root navigator key, shared by the router and route modules.
final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(debugLabel: 'root'),
);

/// The validated routes of the router's own module and every feature.
final routeRegistryProvider = Provider<RouteRegistry>(
  (ref) => RouteRegistry(
    [
      RouterFallbackModule(ref.watch(routerOptionsProvider).placeholderBuilder),
      ...ref.watch(routeModulesProvider),
    ],
    context: RouteBuildContext(
      rootNavigatorKey: ref.watch(rootNavigatorKeyProvider),
    ),
  ),
);

/// The app's single router. Re-runs its guards whenever the
/// authentication state changes.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authenticationStateProvider, (_, _) => refresh.value++);
  final router = createAppRouter(
    registry: ref.watch(routeRegistryProvider),
    options: ref.watch(routerOptionsProvider),
    authentication: () => ref.read(authenticationStateProvider),
    authorizer: ref.watch(routeAuthorizerProvider),
    navigatorKey: ref.watch(rootNavigatorKeyProvider),
    refreshListenable: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Opens notification payloads in the router.
final notificationNavigatorProvider = Provider<NotificationNavigator>(
  (ref) => NotificationNavigator(
    router: ref.watch(routerProvider),
    resolvers: ref.watch(routeRegistryProvider).notificationResolvers,
  ),
);
