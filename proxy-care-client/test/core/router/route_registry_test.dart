import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:proxy_care_client/core/router/navigation_payload.dart';
import 'package:proxy_care_client/core/router/route_access.dart';
import 'package:proxy_care_client/core/router/route_module.dart';
import 'package:proxy_care_client/core/router/router_options.dart';
import 'package:proxy_care_client/core/router/router_placeholder.dart';

final _context = RouteBuildContext(rootNavigatorKey: GlobalKey());

Widget _page(BuildContext context, GoRouterState state) => const SizedBox();

final class _Module extends RouteModule {
  _Module(this.name, this.routes, {this.notifications = const {}});

  @override
  final String name;
  final List<RouteBase> routes;
  final Map<String, NotificationLocationResolver> notifications;

  @override
  List<RouteBase> buildRoutes(RouteBuildContext context) => routes;

  @override
  Map<String, NotificationLocationResolver> get notificationRoutes =>
      notifications;
}

GoRoute _route(
  String path,
  String? name, {
  RouteAccess? access = const PublicAccess(),
  List<RouteBase> routes = const [],
}) => GoRoute(
  path: path,
  name: name,
  builder: _page,
  metadata: access?.asMetadata,
  routes: routes,
);

List<String> _problems(List<RouteModule> modules) {
  try {
    RouteRegistry(modules, context: _context);
    return const [];
  } on RouteConfigurationException catch (error) {
    return error.problems;
  }
}

void main() {
  test('assembles every module, in order', () {
    final registry = RouteRegistry([
      const RouterFallbackModule(defaultRouterPlaceholder),
      _Module(
        'visits',
        [
          _route(
            '/visits',
            'visits.list',
            routes: [_route(':visitId', 'visits.detail', access: null)],
          ),
        ],
        notifications: {'visits.updated': (_) => '/visits'},
      ),
      _Module('profile', [_route('/profile', 'profile.view')]),
    ], context: _context);

    expect(registry.routes, hasLength(6));
    expect(registry.routes.whereType<GoRoute>().map((route) => route.name), [
      'router.pending',
      'router.signInRequired',
      'router.forbidden',
      'router.notFound',
      'visits.list',
      'profile.view',
    ]);
    expect(registry.notificationResolvers.keys, ['visits.updated']);
  });

  test('access may come from an ancestor route or a shell', () {
    expect(
      _problems([
        _Module('visits', [
          ShellRoute(
            metadata: const AuthenticatedAccess().asMetadata,
            builder: (_, _, child) => child,
            routes: [_route('/visits', 'visits.list', access: null)],
          ),
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => shell,
            branches: [
              StatefulShellBranch(
                routes: [_route('/visits/tabs', 'visits.tabs')],
              ),
            ],
          ),
        ]),
      ]),
      isEmpty,
    );
  });

  test('reports every convention problem together', () {
    final problems = _problems([
      _Module('Visits', [_route('/a', 'Visits.a')]),
      _Module('visits', [
        _route('/visits', 'visits.list'),
        _route('/visits-again', 'visits.list'),
        _route('/no-name', null),
        _route('/open', 'visits.open', access: null),
        _route('/Bad_Path', 'visits.bad'),
        _route('/other', 'profile.other'),
      ]),
      _Module(
        'visits',
        [_route('/x', 'visits.x')],
        notifications: {'profile.changed': (_) => '/x'},
      ),
    ]);

    expect(problems, [
      contains('module "Visits" must be lowerCamelCase'),
      contains('route name "Visits.a"'),
      contains('route name "visits.list" is used twice'),
      contains('route "/no-name" in module "visits" has no name'),
      contains('route "visits.open" declares no RouteAccess'),
      contains('"Bad_Path"'),
      contains('route name "profile.other" must be "visits.<screen>"'),
      contains('module "visits" is listed twice'),
      contains('notification type "profile.changed"'),
    ]);
  });

  test('route features must be snake_case flag names', () {
    expect(
      _problems([
        _Module('visits', [
          _route(
            '/visits',
            'visits.list',
            access: const AuthenticatedAccess(feature: 'betaTools'),
          ),
          _route(
            '/beta',
            'visits.beta',
            access: const AuthenticatedAccess(feature: 'beta_tools'),
          ),
        ]),
      ]),
      [contains('feature "betaTools" must be snake_case')],
    );
  });

  test('an empty route tree is rejected', () {
    expect(_problems(const []), ['no routes are registered']);
  });

  test('duplicate notification types are rejected', () {
    String? resolve(NavigationPayload payload) => '/a';
    expect(
      _problems([
        _Module('a', [_route('/a', 'a.page')], notifications: {'a.x': resolve}),
        _Module(
          'b',
          [_route('/b', 'b.page')],
          notifications: {'a.x': resolve},
        ),
      ]),
      [contains('"a.x" must be "b.<event>"'), contains('registered twice')],
    );
  });
}
