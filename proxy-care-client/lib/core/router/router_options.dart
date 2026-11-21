import 'package:go_router/go_router.dart';

import 'deep_link_policy.dart';
import 'redirect_destinations.dart';
import 'route_access.dart';
import 'route_module.dart';
import 'router_placeholder.dart';

/// App-wide router settings, provided by `routerOptionsProvider`.
final class RouterOptions {
  /// Creates the options; every value has a default.
  const RouterOptions({
    this.initialLocation = '/',
    this.destinations = const RedirectDestinations(),
    this.deepLinks = const DeepLinkPolicy(),
    this.placeholderBuilder = defaultRouterPlaceholder,
  });

  /// Where the app starts when the platform supplies no deep link. A deep
  /// link at launch (cold start) always wins.
  final String initialLocation;

  /// Where the guards send users.
  final RedirectDestinations destinations;

  /// Which incoming links are opened.
  final DeepLinkPolicy deepLinks;

  /// What the router's fallback locations and its not-found page show.
  final RouterPlaceholderBuilder placeholderBuilder;
}

/// The router's own routes: the fallback locations in [RouterLocations],
/// all rendered by [placeholderBuilder]. Registered as module `router`.
final class RouterFallbackModule extends RouteModule {
  /// Creates the module.
  const RouterFallbackModule(this.placeholderBuilder);

  /// What the fallbacks show.
  final RouterPlaceholderBuilder placeholderBuilder;

  @override
  String get name => 'router';

  @override
  List<RouteBase> buildRoutes(RouteBuildContext context) => [
    _route(
      'router.pending',
      RouterLocations.pending,
      RouterPlaceholderKind.pending,
      const PublicAccess(),
    ),
    _route(
      'router.signInRequired',
      RouterLocations.signInRequired,
      RouterPlaceholderKind.signInRequired,
      const GuestOnlyAccess(),
    ),
    _route(
      'router.forbidden',
      RouterLocations.forbidden,
      RouterPlaceholderKind.forbidden,
      const PublicAccess(),
    ),
    _route(
      'router.notFound',
      RouterLocations.notFound,
      RouterPlaceholderKind.notFound,
      const PublicAccess(),
    ),
  ];

  GoRoute _route(
    String name,
    String path,
    RouterPlaceholderKind kind,
    RouteAccess access,
  ) => GoRoute(
    name: name,
    path: path,
    metadata: access.asMetadata,
    builder: (context, state) => placeholderBuilder(context, kind, state),
  );
}
