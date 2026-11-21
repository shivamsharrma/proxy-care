import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:proxy_care_client/core/auth/authentication_state.dart';
import 'package:proxy_care_client/core/auth/authorization/authorization.dart';
import 'package:proxy_care_client/core/di/router_providers.dart';
import 'package:proxy_care_client/core/router/app_router.dart';
import 'package:proxy_care_client/core/router/deep_link_policy.dart';
import 'package:proxy_care_client/core/router/notification_navigator.dart';
import 'package:proxy_care_client/core/router/redirect_destinations.dart';
import 'package:proxy_care_client/core/router/route_guards.dart';
import 'package:proxy_care_client/core/router/route_module.dart';
import 'package:proxy_care_client/core/router/router_options.dart';
import 'package:proxy_care_client/core/router/router_placeholder.dart';

import '../../helpers/router_harness.dart';

const _signInOptions = RouterOptions(
  initialLocation: '/public',
  destinations: RedirectDestinations(signIn: '/guest', home: '/home'),
  deepLinks: DeepLinkPolicy(allowedHosts: {'links.example.test'}),
  placeholderBuilder: labelledPlaceholder,
);

void main() {
  group('initialization and registration', () {
    testWidgets('starts at the initial location with every module routed', (
      tester,
    ) async {
      final harness = await RouterHarness.pump(tester);

      expect(harness.location, '/public');
      expect(find.text('public'), findsOneWidget);
      final names = harness.container
          .read(routeRegistryProvider)
          .routes
          .whereType<GoRoute>()
          .map((route) => route.name);
      expect(names, containsAll(['router.notFound', 'test.home']));
      expect(
        harness.module.rootNavigatorKey,
        same(harness.container.read(rootNavigatorKeyProvider)),
      );
      expect(harness.router, same(harness.container.read(routerProvider)));
    });

    test('rejects destinations that are not in-app locations', () {
      expect(
        () => createAppRouter(
          registry: RouteRegistry([
            const RouterFallbackModule(defaultRouterPlaceholder),
          ], context: RouteBuildContext(rootNavigatorKey: GlobalKey())),
          options: const RouterOptions(
            destinations: RedirectDestinations(signIn: 'https://x.test/'),
          ),
          authentication: () => const Unauthenticated(),
          authorizer: const RouteAuthorizer(
            authorization: AuthorizationService(RolePermissionPolicy.none),
            features: FeatureFlagAccessPolicy({}),
          ),
          navigatorKey: GlobalKey(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('authentication redirects', () {
    testWidgets('a protected route waits for sign-in, then continues', (
      tester,
    ) async {
      final harness = await RouterHarness.pump(tester, options: _signInOptions);

      await harness.go(tester, '/items/42?tab=notes');
      expect(harness.uri.path, '/guest');
      expect(harness.uri.queryParameters['from'], '/items/42?tab=notes');
      expect(find.text('guest'), findsOneWidget);

      await harness.emit(tester, signedIn());
      expect(harness.location, '/items/42?tab=notes');
      expect(find.text('item 42 tab notes extra -'), findsOneWidget);
    });

    testWidgets('without a sign-in route, the fallback is shown', (
      tester,
    ) async {
      final harness = await RouterHarness.pump(tester);

      await harness.go(tester, '/home');
      expect(harness.uri.path, RouterLocations.signInRequired);
      expect(harness.uri.queryParameters['from'], '/home');
      expect(find.text('placeholder signInRequired'), findsOneWidget);

      await harness.emit(tester, signedIn());
      expect(harness.location, '/home', reason: 'intended destination kept');
    });

    testWidgets('a signed-in user leaves guest-only routes', (tester) async {
      final harness = await RouterHarness.pump(
        tester,
        auth: signedIn(),
        options: _signInOptions,
      );

      await harness.go(tester, '/guest');
      expect(harness.location, '/home');
    });

    testWidgets('an expired session leaves the protected route', (
      tester,
    ) async {
      final harness = await RouterHarness.pump(
        tester,
        auth: signedIn(),
        options: _signInOptions,
      );
      await harness.go(tester, '/items/7');
      expect(find.text('item 7 tab - extra -'), findsOneWidget);

      await harness.emit(tester, const SessionExpired());
      expect(harness.uri.path, '/guest');
      expect(harness.uri.queryParameters, {
        'from': '/items/7',
        'reason': 'sessionExpired',
      });

      await harness.emit(tester, signedIn());
      expect(harness.location, '/items/7');
    });

    testWidgets('signing out on a protected route redirects', (tester) async {
      final harness = await RouterHarness.pump(
        tester,
        auth: signedIn(),
        options: _signInOptions,
      );
      await harness.go(tester, '/home');

      await harness.emit(tester, const Unauthenticated());
      expect(harness.uri.path, '/guest');
      expect(harness.uri.queryParameters['from'], '/home');
    });

    testWidgets('initializing users wait, then go on', (tester) async {
      final harness = await RouterHarness.pump(
        tester,
        auth: const AuthenticationInitializing(),
        options: _signInOptions,
      );

      await harness.go(tester, '/home');
      expect(harness.uri.path, RouterLocations.pending);
      expect(find.text('placeholder pending'), findsOneWidget);

      await harness.emit(tester, signedIn());
      expect(harness.location, '/home');
    });

    testWidgets('public routes stay open in every state', (tester) async {
      final harness = await RouterHarness.pump(tester);
      for (final state in [const SessionExpired(), signedIn()]) {
        await harness.emit(tester, state);
        expect(harness.location, '/public');
      }
    });
  });

  group('authorization redirects', () {
    testWidgets('a missing role goes to forbidden', (tester) async {
      final harness = await RouterHarness.pump(tester, auth: signedIn());

      await harness.go(tester, '/admin');
      expect(harness.location, RouterLocations.forbidden);
      expect(find.text('placeholder forbidden'), findsOneWidget);
    });

    testWidgets('the right role or permission opens the route', (
      tester,
    ) async {
      const admin = Role('admin');
      final harness = await RouterHarness.pump(
        tester,
        auth: signedIn(roles: {admin}),
        grants: {
          admin: {const Permission('reports.read')},
        },
      );

      await harness.go(tester, '/admin');
      expect(find.text('admin'), findsOneWidget);
      await harness.go(tester, '/reports');
      expect(find.text('reports'), findsOneWidget);
    });

    testWidgets('a missing permission goes to forbidden', (tester) async {
      final harness = await RouterHarness.pump(tester, auth: signedIn());

      await harness.go(tester, '/reports');
      expect(harness.location, RouterLocations.forbidden);
    });

    testWidgets('feature routes follow the feature flags', (tester) async {
      final off = await RouterHarness.pump(tester, auth: signedIn());
      await off.go(tester, '/beta');
      expect(off.location, RouterLocations.forbidden);
    });

    testWidgets('an enabled feature opens', (tester) async {
      final on = await RouterHarness.pump(
        tester,
        auth: signedIn(),
        featureFlags: 'beta_tools',
      );
      await on.go(tester, '/beta');
      expect(find.text('beta'), findsOneWidget);
    });

    testWidgets('losing a role while on the route redirects', (tester) async {
      const admin = Role('admin');
      final harness = await RouterHarness.pump(
        tester,
        auth: signedIn(roles: {admin}),
      );
      await harness.go(tester, '/admin');
      expect(find.text('admin'), findsOneWidget);

      await harness.emit(tester, signedIn());
      expect(harness.location, RouterLocations.forbidden);
    });
  });

  group('nested navigation', () {
    testWidgets('push stacks a route and back returns', (tester) async {
      final harness = await RouterHarness.pump(tester, auth: signedIn());
      await harness.go(tester, '/items');

      harness.router.push('/items/3', extra: 'preloaded');
      await tester.pumpAndSettle();
      expect(find.text('item 3 tab - extra preloaded'), findsOneWidget);
      expect(harness.router.canPop(), isTrue);

      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('items'), findsOneWidget);
      expect(harness.location, '/items');
    });

    testWidgets('go builds the parent stack; extras are optional', (
      tester,
    ) async {
      final harness = await RouterHarness.pump(tester, auth: signedIn());

      await harness.go(tester, '/items/5/edit');
      expect(find.text('edit'), findsOneWidget);
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('item 5 tab - extra -'), findsOneWidget);
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('items'), findsOneWidget);
    });

    testWidgets('a ShellRoute wraps its child in shared chrome', (
      tester,
    ) async {
      final harness = await RouterHarness.pump(tester, auth: signedIn());

      await harness.go(tester, '/shell/page');
      expect(find.text('shell chrome'), findsOneWidget);
      expect(find.text('page'), findsOneWidget);
    });

    testWidgets('a ShellRoute inherits its access', (tester) async {
      final harness = await RouterHarness.pump(tester);

      await harness.go(tester, '/shell/page');
      expect(harness.uri.path, RouterLocations.signInRequired);
    });

    testWidgets('StatefulShellRoute keeps each branch stack', (tester) async {
      final harness = await RouterHarness.pump(tester, auth: signedIn());

      await harness.go(tester, '/tabs/one/detail');
      expect(find.text('tab one detail'), findsOneWidget);

      harness.module.navigationShell!.goBranch(1);
      await tester.pumpAndSettle();
      expect(harness.location, '/tabs/two');
      expect(find.text('tab two'), findsOneWidget);

      harness.module.navigationShell!.goBranch(0);
      await tester.pumpAndSettle();
      expect(harness.location, '/tabs/one/detail');
      expect(find.text('tab one detail'), findsOneWidget);

      harness.module.navigationShell!.goBranch(0, initialLocation: true);
      await tester.pumpAndSettle();
      expect(harness.location, '/tabs/one');
    });

    testWidgets('a root-navigator route covers the shell', (tester) async {
      final harness = await RouterHarness.pump(tester, auth: signedIn());
      await harness.go(tester, '/tabs/two');

      harness.router.push('/full-screen');
      await tester.pumpAndSettle();
      expect(find.text('full screen'), findsOneWidget);
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.text('tab two'), findsOneWidget);
    });
  });

  group('deep links', () {
    testWidgets('a cold-start link is guarded and preserved', (tester) async {
      tester.platformDispatcher.defaultRouteNameTestValue =
          'https://links.example.test/items/9?tab=a';
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      final harness = await RouterHarness.pump(tester, options: _signInOptions);
      expect(harness.uri.path, '/guest');
      expect(harness.uri.queryParameters['from'], '/items/9?tab=a');

      await harness.emit(tester, signedIn());
      expect(harness.location, '/items/9?tab=a');
      expect(find.text('item 9 tab a extra -'), findsOneWidget);
    });

    testWidgets('a link while running opens its location', (tester) async {
      final harness = await RouterHarness.pump(
        tester,
        auth: signedIn(),
        options: _signInOptions,
      );

      await harness.openPlatformLink(
        tester,
        'https://links.example.test/items/12',
      );
      expect(harness.location, '/items/12');
      expect(find.text('item 12 tab - extra -'), findsOneWidget);
    });

    testWidgets('a link to another host is not opened', (tester) async {
      final harness = await RouterHarness.pump(
        tester,
        auth: signedIn(),
        options: _signInOptions,
      );

      await harness.openPlatformLink(tester, 'https://evil.example/items/12');
      expect(harness.location, RouterLocations.notFound);
      expect(find.text('placeholder notFound'), findsOneWidget);
    });
  });

  group('invalid routes', () {
    testWidgets('an unknown location shows the not-found fallback', (
      tester,
    ) async {
      final harness = await RouterHarness.pump(tester, auth: signedIn());

      await harness.go(tester, '/does-not-exist');
      expect(find.text('placeholder notFound'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('notification navigation', () {
    testWidgets('a valid payload opens its route', (tester) async {
      final harness = await RouterHarness.pump(tester, auth: signedIn());
      final navigator = harness.container.read(notificationNavigatorProvider);

      final outcome = navigator.open({
        'type': 'test.itemUpdated',
        'data': {'itemId': '5'},
      });
      await tester.pumpAndSettle();

      expect(outcome, NotificationNavigationOutcome.navigated);
      expect(harness.location, '/items/5');
    });

    testWidgets('a protected target while signed out keeps the target', (
      tester,
    ) async {
      final harness = await RouterHarness.pump(tester, options: _signInOptions);
      final navigator = harness.container.read(notificationNavigatorProvider);

      navigator.open({
        'type': 'test.itemUpdated',
        'data': {'itemId': '5'},
      });
      await tester.pumpAndSettle();

      expect(harness.uri.path, '/guest');
      expect(harness.uri.queryParameters['from'], '/items/5');
    });

    testWidgets('invalid, unknown and unresolved payloads do nothing', (
      tester,
    ) async {
      final harness = await RouterHarness.pump(tester, auth: signedIn());
      final navigator = harness.container.read(notificationNavigatorProvider);

      expect(
        navigator.open({'type': 42}),
        NotificationNavigationOutcome.invalidPayload,
      );
      expect(
        navigator.open({'type': 'other.event'}),
        NotificationNavigationOutcome.unknownType,
      );
      expect(
        navigator.open({'type': 'test.itemUpdated'}),
        NotificationNavigationOutcome.unresolved,
      );
      await tester.pumpAndSettle();
      expect(harness.location, '/public');
    });
  });
}
