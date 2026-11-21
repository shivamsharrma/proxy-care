import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/auth/authentication_state.dart';
import 'package:proxy_care_client/core/auth/authorization/authorization.dart';
import 'package:proxy_care_client/core/di/app_container.dart';
import 'package:proxy_care_client/core/di/auth_providers.dart';
import 'package:proxy_care_client/core/di/router_providers.dart';
import 'package:proxy_care_client/core/router/navigation_payload.dart';
import 'package:proxy_care_client/core/router/route_access.dart';
import 'package:proxy_care_client/core/router/route_definition.dart';
import 'package:proxy_care_client/core/router/route_module.dart';
import 'package:proxy_care_client/core/router/router_options.dart';
import 'package:proxy_care_client/core/router/router_placeholder.dart';

import '../fixtures/env_fixtures.dart';
import 'auth_fakes.dart';

/// Test-only route definitions. They exist to exercise the router; they
/// are not product routes.
abstract final class TestRoutes {
  static const public = RouteDefinition(
    name: 'test.public',
    path: '/public',
    access: PublicAccess(),
  );
  static const guest = RouteDefinition(
    name: 'test.guest',
    path: '/guest',
    access: GuestOnlyAccess(),
  );
  static const home = RouteDefinition(
    name: 'test.home',
    path: '/home',
    access: AuthenticatedAccess(),
  );
  static const items = RouteDefinition(
    name: 'test.items',
    path: '/items',
    access: AuthenticatedAccess(),
  );
  static const item = RouteDefinition(
    name: 'test.item',
    path: ':itemId',
    parent: items,
  );
  static const itemEdit = RouteDefinition(
    name: 'test.item.edit',
    path: 'edit',
    parent: item,
  );
  static final admin = RouteDefinition(
    name: 'test.admin',
    path: '/admin',
    access: AuthenticatedAccess(anyOfRoles: {const Role('admin')}),
  );
  static final reports = RouteDefinition(
    name: 'test.reports',
    path: '/reports',
    access: AuthenticatedAccess(
      permissions: {const Permission('reports.read')},
    ),
  );
  static const beta = RouteDefinition(
    name: 'test.beta',
    path: '/beta',
    access: AuthenticatedAccess(feature: 'beta_tools'),
  );
  static const shellPage = RouteDefinition(
    name: 'test.shellPage',
    path: '/shell/page',
  );
  static const tabOne = RouteDefinition(
    name: 'test.tabOne',
    path: '/tabs/one',
    access: AuthenticatedAccess(),
  );
  static const tabOneDetail = RouteDefinition(
    name: 'test.tabOne.detail',
    path: 'detail',
    parent: tabOne,
  );
  static const tabTwo = RouteDefinition(
    name: 'test.tabTwo',
    path: '/tabs/two',
    access: AuthenticatedAccess(),
  );
  static const fullScreen = RouteDefinition(
    name: 'test.fullScreen',
    path: '/full-screen',
    access: AuthenticatedAccess(),
  );
}

/// A route module with the [TestRoutes], a plain shell and a stateful
/// (tabbed) shell, plus one notification type.
final class TestRouteModule extends RouteModule {
  TestRouteModule();

  /// The tabbed shell's navigation, captured when it builds.
  StatefulNavigationShell? navigationShell;

  /// The root navigator key the module received.
  GlobalKey<NavigatorState>? rootNavigatorKey;

  @override
  String get name => 'test';

  @override
  Map<String, NotificationLocationResolver> get notificationRoutes => {
    'test.itemUpdated': (payload) {
      final id = payload.data['itemId'];
      return id == null
          ? null
          : TestRoutes.item.location(pathParameters: {'itemId': id});
    },
  };

  @override
  List<RouteBase> buildRoutes(RouteBuildContext context) {
    rootNavigatorKey = context.rootNavigatorKey;
    return [
      TestRoutes.public.route(builder: (_, _) => const Text('public')),
      TestRoutes.guest.route(builder: (_, _) => const Text('guest')),
      TestRoutes.home.route(builder: (_, _) => const Text('home')),
      TestRoutes.items.route(
        builder: (_, _) => const Text('items'),
        routes: [
          TestRoutes.item.route(
            builder: (_, state) {
              final id = state.requirePathParameter('itemId');
              final tab = state.uri.queryParameters['tab'] ?? '-';
              final extra = state.extra as String?;
              return Text('item $id tab $tab extra ${extra ?? '-'}');
            },
            routes: [
              TestRoutes.itemEdit.route(builder: (_, _) => const Text('edit')),
            ],
          ),
        ],
      ),
      TestRoutes.admin.route(builder: (_, _) => const Text('admin')),
      TestRoutes.reports.route(builder: (_, _) => const Text('reports')),
      TestRoutes.beta.route(builder: (_, _) => const Text('beta')),
      ShellRoute(
        metadata: const AuthenticatedAccess().asMetadata,
        builder: (_, _, child) => Column(
          children: [
            const Text('shell chrome'),
            Expanded(child: child),
          ],
        ),
        routes: [
          TestRoutes.shellPage.route(builder: (_, _) => const Text('page')),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => navigationShell = shell,
        branches: [
          StatefulShellBranch(
            routes: [
              TestRoutes.tabOne.route(
                builder: (_, _) => const Text('tab one'),
                routes: [
                  TestRoutes.tabOneDetail.route(
                    builder: (_, _) => const Text('tab one detail'),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              TestRoutes.tabTwo.route(builder: (_, _) => const Text('tab two')),
            ],
          ),
        ],
      ),
      TestRoutes.fullScreen.route(
        parentNavigatorKey: context.rootNavigatorKey,
        builder: (_, _) => const Text('full screen'),
      ),
    ];
  }
}

/// A placeholder builder that shows which fallback is displayed.
Widget labelledPlaceholder(
  BuildContext context,
  RouterPlaceholderKind kind,
  GoRouterState state,
) => Text('placeholder ${kind.name}');

/// Delivers [link] as the platform does for an App Link or Universal Link
/// while the app is running, then settles.
Future<void> deliverPlatformLink(WidgetTester tester, String link) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      MethodCall('pushRouteInformation', {'location': link, 'state': null}),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// A user, optionally with [roles].
Authenticated signedIn({Set<Role> roles = const {}}) => Authenticated(
  user: AuthenticatedUser(id: 'user-1', roles: roles),
);

/// The router, its container and the fake session behind it.
final class RouterHarness {
  RouterHarness._(this.container, this.session, this.module);

  final ProviderContainer container;
  final FakeAuthenticationSession session;
  final TestRouteModule module;

  GoRouter get router => container.read(routerProvider);

  /// The current location (path and query).
  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  /// The current location as a URI.
  Uri get uri => Uri.parse(location);

  /// Sends the session to [state] and lets the router react.
  Future<void> emit(WidgetTester tester, AuthenticationState state) async {
    session.emit(state);
    await tester.pumpAndSettle();
  }

  /// Navigates with `go` and settles.
  Future<void> go(WidgetTester tester, String location, {Object? extra}) async {
    router.go(location, extra: extra);
    await tester.pumpAndSettle();
  }

  /// Delivers [link] as the platform does while the app is running.
  Future<void> openPlatformLink(WidgetTester tester, String link) =>
      deliverPlatformLink(tester, link);

  /// Pumps an app around the router.
  static Future<RouterHarness> pump(
    WidgetTester tester, {
    AuthenticationState auth = const Unauthenticated(),
    RouterOptions options = const RouterOptions(
      initialLocation: '/public',
      placeholderBuilder: labelledPlaceholder,
    ),
    String featureFlags = '',
    Map<Role, Set<Permission>> grants = const {},
    List<Override> overrides = const [],
  }) async {
    final session = FakeAuthenticationSession()..currentState = auth;
    final module = TestRouteModule();
    final container = createAppContainer(
      env: testEnv(featureFlags: featureFlags),
      overrides: [
        authenticationSessionProvider.overrideWithValue(session),
        routeModulesProvider.overrideWithValue([module]),
        routerOptionsProvider.overrideWithValue(options),
        authorizationServiceProvider.overrideWithValue(
          AuthorizationService(RolePermissionPolicy(grants)),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: container.read(routerProvider)),
      ),
    );
    await tester.pumpAndSettle();
    return RouterHarness._(container, session, module);
  }
}
