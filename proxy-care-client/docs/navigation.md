# Navigation

Routing uses go_router 18. There is exactly one `GoRouter`
(`routerProvider`, built by `createAppRouter` in `core/router/app_router.dart`)
wired once through `MaterialApp.router` in `app.dart`. Features never create
a router. No product routes exist yet; only the router's own fallback
locations are registered.

## How routes are registered

```text
lib/app_routes.dart            appRouteModules = [BookingsRoutes(), ...]
        │  (main.dart overrides routeModulesProvider with
        │   enabledRouteModules(env): these plus dev-only modules)
        ▼
core/di/router_providers.dart  routeRegistryProvider ─► RouteRegistry
        │                         (validates every module)
        ▼                       routerProvider ─► createAppRouter
features/<f>/<f>_routes.dart   class <F>Routes extends RouteModule
```

A feature adds one file, `features/<feature>/<feature>_routes.dart`, with
its `RouteDefinition`s and a `RouteModule`, and one line in
`lib/app_routes.dart`. `core` never imports features (an architecture test
enforces this). `RouteRegistry` rejects, all at once and at start-up:

- a module name that is not lowerCamelCase, or listed twice;
- a `GoRoute` without a name, with a name not starting with `<module>.`, or
  a name used twice;
- a path that breaks the path rules below;
- a route with no `RouteAccess` on itself or an ancestor;
- a notification type not starting with `<module>.`, or registered twice.

## Conventions

| Thing | Rule | Example |
| --- | --- | --- |
| Module | lowerCamelCase, one per feature | `bookings` |
| Route name | `<module>.<screen>[.<sub>]`, lowerCamelCase parts | `bookings.detail.edit` |
| Path | absolute at top level (and directly under a top-level shell), relative when nested; kebab-case segments | `/care-visits`, `:visitId`, `edit` |
| Path parameter | `:lowerCamelCase`, no regex constraints; the **identity** of what is shown | `:bookingId` |
| Query parameter | lowerCamelCase key; optional view state (tab, filter, page) | `?tab=notes` |
| Reserved query keys | `from`, `reason` (router only) | |
| Extras | an optional pre-loaded object to avoid a loading flash; never identity, never required | `extra: booking` |
| Internal segment `_` | reserved for router fallbacks | `/_/forbidden` |

Rules behind them:

- **Identity goes in the path.** A screen must be rebuildable from its URL
  alone: after a cold-start deep link, a web reload or process death,
  `state.extra` is null. Read ids with `state.requirePathParameter('id')`.
- **Build locations from definitions**, never by concatenating strings:
  `BookingRoutes.detail.location(pathParameters: {'bookingId': id})`. It
  URL-encodes values and rejects missing, unknown, empty or reserved keys.
- **Extras are optional.** `state.extra as Booking?`, then load by id when
  it is null. On web, extras do not survive a reload.
- **Validate query values in the screen's controller**; they come from
  URLs anyone can type.

```dart
// features/bookings/bookings_routes.dart (illustration only)
abstract final class BookingRoutes {
  static const list = RouteDefinition(
    name: 'bookings.list', path: '/bookings', access: AuthenticatedAccess());
  static const detail = RouteDefinition(
    name: 'bookings.detail', path: ':bookingId', parent: list);
}

final class BookingsRoutes extends RouteModule {
  const BookingsRoutes();
  @override
  String get name => 'bookings';
  @override
  List<RouteBase> buildRoutes(RouteBuildContext context) => [
    BookingRoutes.list.route(
      builder: (_, _) => const BookingListScreen(),
      routes: [
        BookingRoutes.detail.route(
          builder: (_, state) => BookingDetailScreen(
            bookingId: state.requirePathParameter('bookingId'),
            preloaded: state.extra as Booking?,
          ),
        ),
      ],
    ),
  ];
}
```

## Access and guards

Every route declares a `RouteAccess`; children inherit it and may
override it. A missing access is treated as authenticated.

| Access | Signed out | Initializing | Session expired | Signed in |
| --- | --- | --- | --- | --- |
| `PublicAccess()` | open | open | open | open |
| `GuestOnlyAccess()` | open | open | open | continue to `from`, else `home`, else stay |
| `AuthenticatedAccess(...)` | → sign-in `?from=` | → pending `?from=` | → session-expired `?from=&reason=sessionExpired` | open if authorized, else → forbidden |

The top-level redirect runs three pure guards in order:

1. `DeepLinkGuard`: full `https` links on an allowed host become in-app
   locations; anything else goes to not-found.
2. `AuthenticationGuard`: the table above.
3. `AuthorizationGuard`: `AuthenticatedAccess.anyOfRoles` (at least one),
   `permissions` (all, through `AuthorizationService`) and `feature`
   (`FeatureAccessPolicy`, by default the `FEATURE_FLAGS` setting).

The guards read the authentication state on every navigation, and
`routerProvider` refreshes the router whenever `authenticationStateProvider`
changes, so signing in resumes the intended destination, and an expired
session or a lost role leaves a protected route immediately. Authorization
is evaluated by `RouteAuthorizer`, not by widgets, and is only a UI hint:
the API enforces access.

**Intended destination.** The interrupted location (path and query) travels
as `from` in the redirect target's URL, so it survives cold starts and
reloads. It is only ever restored after `IntendedDestination.sanitize`,
which accepts in-app paths only (no scheme, host, `//`, backslash or `..`),
so a crafted `from` cannot redirect off-site.

**Destinations are configurable** through `routerOptionsProvider`
(`RedirectDestinations`: `signIn`, `sessionExpired`, `home`, `forbidden`,
`pending`, `notFound`). None is set yet; until a feature provides a route,
each falls back to a router location under `/_/` that renders the
configurable `RouterOptions.placeholderBuilder` (nothing by default). A
sign-in route must be `GuestOnlyAccess` (or public); a redirect to the
current location is treated as "allow", so a misconfiguration cannot loop.

## Which navigation mechanism to use

| Need | Use | Navigate with |
| --- | --- | --- |
| A destination the user switches to (a section, the post-sign-in landing) | top-level `GoRoute` | `context.go(location)`: replaces the stack |
| A screen the user returns from (detail, form, step) | nested `GoRoute` under its parent | `context.push(location)` (stacks; back returns) or `context.go` to build the whole parent chain, for deep links |
| Back | the system back button / `context.pop([result])` | `PopScope` (`canPop` + `onPopInvokedWithResult`) to confirm discarding changes |
| Shared chrome around several routes with **one** stack (a wizard frame) | `ShellRoute` (with `metadata: access.asMetadata`) | `go` / `push` as usual |
| Tabs or a rail where **each section keeps its own stack** | `StatefulShellRoute.indexedStack` with one `StatefulShellBranch` per tab | `navigationShell.goBranch(i)`; `initialLocation: i == currentIndex` returns a re-tapped tab to its root |
| A full-screen flow over the tabs | a `GoRoute` with `parentNavigatorKey: context.rootNavigatorKey` (from `RouteBuildContext`) | `push` |
| A custom transition | `pageBuilder` returning `CustomTransitionPage`, collapsing to no animation when `MediaQuery.disableAnimationsOf(context)` | |

`StatefulShellRoute` takes no metadata: declare access on each branch's
routes. Choose bottom bar versus rail by available width in the shell
widget, never in the router.

## Deep links and notifications

- go_router consumes incoming links itself: at a **cold start** the
  platform's initial link replaces `RouterOptions.initialLocation`; **while
  running** the platform pushes it to the router. Both pass the same guards,
  so a protected link while signed out lands on sign-in and continues after
  it. Platform setup is in [deep-linking.md](deep-linking.md); no domain is
  configured yet (`RouterOptions.deepLinks.allowedHosts` is empty).
- **Notifications:** push delivery is not implemented. A future integration
  hands each tapped payload to `notificationNavigatorProvider.open(payload)`.
  The payload must be `{"type": "<module>.<event>", "data": {<string map>}}`;
  it is validated by `NavigationPayload`, mapped to a location by the owning
  module's `notificationRoutes` resolver (pure, built with
  `RouteDefinition.location`), checked by `IntendedDestination.sanitize`,
  then opened with `go`, so the guards apply.

## Testing

`test/helpers/router_harness.dart` pumps the real router with test-only
route modules and a fake authentication session. Router tests cover
initialization, registration, authentication and authorization redirects,
intended destinations, nested and shell navigation, cold-start and
running deep links, notification payloads and unknown routes.

Deviation from the `navigation-and-routing` skill: it places the router in
`lib/routing/`; this project keeps the existing `lib/core/router/` folder
(set up in Milestone 1) so infrastructure stays under `core`.
