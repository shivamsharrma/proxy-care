# core/router

The app's single GoRouter and its building blocks. Conventions and when
to use each navigation mechanism: [docs/navigation.md](../../../docs/navigation.md).
Native App Links / Universal Links: [docs/deep-linking.md](../../../docs/deep-linking.md).

Pure Dart (no Flutter, no go_router):

- `route_conventions.dart`: naming rules for modules, routes, paths, query
  keys; the router's reserved query keys (`from`, `reason`).
- `route_access.dart`: `PublicAccess`, `GuestOnlyAccess`,
  `AuthenticatedAccess(anyOfRoles, permissions, feature)`.
- `route_guards.dart`: `RouteRequest`, `RouteGuard`, `RedirectPipeline`,
  `DeepLinkGuard`, `AuthenticationGuard`, `AuthorizationGuard`,
  `RouteAuthorizer`, `FeatureAccessPolicy`.
- `intended_destination.dart`: keeps and safely restores the interrupted
  location.
- `deep_link_policy.dart`: which incoming links are opened.
- `navigation_payload.dart`: validated notification payloads.
- `redirect_destinations.dart`: configurable redirect targets and the
  router's fallback locations.

Flutter / go_router:

- `route_definition.dart`: `RouteDefinition` (name, path, parent, access;
  builds the `GoRoute` and typed locations) and `GoRouterState` helpers.
- `route_module.dart`: `RouteModule` (a feature's routes) and
  `RouteRegistry` (validation and assembly).
- `router_options.dart`: `RouterOptions` and the fallback routes module.
- `router_placeholder.dart`: what fallbacks render (nothing, until product
  screens replace it).
- `app_router.dart`: `createAppRouter`, the only `GoRouter(...)` call.
- `notification_navigator.dart`: the entry point for notification taps.

Providers are in `core/di/router_providers.dart`; the feature list is in
`lib/app_routes.dart`.
