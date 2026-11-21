import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../auth/authentication_state.dart';
import 'intended_destination.dart';
import 'route_access.dart';
import 'route_guards.dart';
import 'route_module.dart';
import 'router_options.dart';
import 'router_placeholder.dart';

/// Builds the app's single `GoRouter`. Only `routerProvider` calls this
/// (tests call it directly); features never create a router.
///
/// [authentication] is read on every redirect, and [refreshListenable]
/// must fire when it changes so the guards run again (for example when a
/// session expires on a protected route).
GoRouter createAppRouter({
  required RouteRegistry registry,
  required RouterOptions options,
  required AuthenticationState Function() authentication,
  required RouteAuthorizer authorizer,
  required GlobalKey<NavigatorState> navigatorKey,
  Listenable? refreshListenable,
  List<NavigatorObserver>? observers,
}) {
  final destinations = options.destinations;
  for (final location in [
    options.initialLocation,
    ...destinations.configured,
  ]) {
    if (IntendedDestination.sanitize(location) == null) {
      throw ArgumentError.value(location, 'options', 'not an in-app location');
    }
  }

  final pipeline = RedirectPipeline([
    DeepLinkGuard(policy: options.deepLinks, destinations: destinations),
    AuthenticationGuard(destinations),
    AuthorizationGuard(authorizer: authorizer, destinations: destinations),
  ]);

  return GoRouter(
    routes: registry.routes,
    navigatorKey: navigatorKey,
    initialLocation: options.initialLocation,
    refreshListenable: refreshListenable,
    observers: observers,
    redirect: (context, state) =>
        pipeline.redirect(_routeRequestOf(state, authentication())),
    errorBuilder: (context, state) => options.placeholderBuilder(
      context,
      RouterPlaceholderKind.notFound,
      state,
    ),
  );
}

/// The guard input for a top-level redirect [state].
RouteRequest _routeRequestOf(
  GoRouterState state,
  AuthenticationState authentication,
) => RouteRequest(
  uri: state.uri,
  matchedLocation: state.matchedLocation,
  access: RouteAccess.fromMetadata(state.metadata),
  authentication: authentication,
  isUnmatched: state.topRoute == null || state.error != null,
);
