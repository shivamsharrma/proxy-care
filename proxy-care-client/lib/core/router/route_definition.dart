import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_access.dart';
import 'route_conventions.dart';

/// One route's identity: name, path, parent and access, declared once by
/// its feature and used both to register the route ([route]) and to build
/// links to it ([location]), so call sites never concatenate paths.
///
/// ```dart
/// // features/bookings/bookings_routes.dart (example, not real code)
/// static const list = RouteDefinition(
///   name: 'bookings.list',
///   path: '/bookings',
///   access: AuthenticatedAccess(),
/// );
/// static const detail = RouteDefinition(
///   name: 'bookings.detail',
///   path: ':bookingId',
///   parent: list,
/// );
///
/// context.push(detail.location(pathParameters: {'bookingId': id}));
/// ```
///
/// Definitions whose access holds roles or permissions cannot be `const`
/// (those types define equality); declare them `static final`.
final class RouteDefinition {
  /// Creates a definition. [path] is relative to [parent] when there is
  /// one, absolute otherwise. [access] is inherited from [parent] when
  /// null.
  const RouteDefinition({
    required this.name,
    required this.path,
    this.parent,
    this.access,
  });

  /// The route name, `<module>.<screen>` (see `RouteConventions`).
  final String name;

  /// The path as registered: absolute for top-level routes, relative for
  /// nested ones.
  final String path;

  /// The enclosing route, for nested routes.
  final RouteDefinition? parent;

  /// The route's access, or null to inherit the parent's.
  final RouteAccess? access;

  /// The absolute path template, for example `/bookings/:bookingId`.
  String get fullPath {
    final parent = this.parent;
    if (parent == null) return path;
    final base = parent.fullPath;
    return base.endsWith('/') ? '$base$path' : '$base/$path';
  }

  /// The path parameter names, in order.
  List<String> get pathParameterNames => [
    for (final segment in fullPath.split('/'))
      if (segment.startsWith(':')) segment.substring(1),
  ];

  /// The location of this route with [pathParameters] filled in (each
  /// value URL-encoded) and optional [queryParameters].
  ///
  /// Throws an [ArgumentError] for a missing, unknown or empty path
  /// parameter, a query key that is not lowerCamelCase, or a key the
  /// router reserves (`from`, `reason`).
  String location({
    Map<String, String> pathParameters = const {},
    Map<String, String> queryParameters = const {},
  }) {
    final expected = pathParameterNames.toSet();
    final given = pathParameters.keys.toSet();
    if (!expected.containsAll(given) || !given.containsAll(expected)) {
      throw ArgumentError.value(
        given.toList(),
        'pathParameters',
        '$name needs exactly ${expected.toList()}',
      );
    }
    for (final key in queryParameters.keys) {
      if (!RouteConventions.isQueryKey(key) ||
          RouterQueryKeys.reserved.contains(key)) {
        throw ArgumentError.value(key, 'queryParameters', 'not allowed');
      }
    }
    final segments = [
      for (final segment in fullPath.split('/'))
        segment.startsWith(':')
            ? _encode(
                segment.substring(1),
                pathParameters[segment.substring(1)]!,
              )
            : segment,
    ];
    final path = segments.join('/');
    if (queryParameters.isEmpty) return path;
    return '$path?${Uri(queryParameters: queryParameters).query}';
  }

  /// The `GoRoute` for this definition, with its name, path and access.
  GoRoute route({
    GoRouterWidgetBuilder? builder,
    GoRouterPageBuilder? pageBuilder,
    GoRouterRedirect? redirect,
    ExitCallback? onExit,
    GlobalKey<NavigatorState>? parentNavigatorKey,
    List<RouteBase> routes = const [],
  }) {
    return GoRoute(
      path: path,
      name: name,
      builder: builder,
      pageBuilder: pageBuilder,
      redirect: redirect,
      onExit: onExit,
      parentNavigatorKey: parentNavigatorKey,
      metadata: access?.asMetadata,
      routes: routes,
    );
  }

  String _encode(String key, String value) {
    if (value.isEmpty) {
      throw ArgumentError.value(value, key, '$name: empty path parameter');
    }
    return Uri.encodeComponent(value);
  }

  @override
  String toString() => 'RouteDefinition($name, $fullPath)';
}

/// Reading parameters inside a route builder.
extension RouteParameters on GoRouterState {
  /// The path parameter [name]. Throws a [StateError] when the matched
  /// route has no such parameter (a route-definition bug).
  String requirePathParameter(String name) {
    final value = pathParameters[name];
    if (value == null) {
      throw StateError('Route ${this.name ?? fullPath} has no :$name');
    }
    return value;
  }
}
