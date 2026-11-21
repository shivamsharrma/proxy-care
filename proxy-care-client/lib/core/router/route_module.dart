import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../config/env.dart';
import 'navigation_payload.dart';
import 'route_access.dart';
import 'route_conventions.dart';

/// What a module may use while building its routes.
final class RouteBuildContext {
  /// Creates the context.
  const RouteBuildContext({required this.rootNavigatorKey});

  /// The app's root navigator. Use it as `parentNavigatorKey` for a route
  /// that must cover a shell (a full-screen flow over tabs).
  final GlobalKey<NavigatorState> rootNavigatorKey;
}

/// A feature's contribution to the router.
///
/// Each feature implements one module in
/// `features/<feature>/<feature>_routes.dart` and lists it in
/// `lib/app_routes.dart`. The router never knows features by name; all
/// routes stay with the feature that owns them.
abstract class RouteModule {
  /// Const constructor for subclasses.
  const RouteModule();

  /// The module name (lowerCamelCase). Every route name and notification
  /// type of the module starts with `<name>.`.
  String get name;

  /// The module's top-level routes (`GoRoute`, `ShellRoute` or
  /// `StatefulShellRoute`). Every route must declare a [RouteAccess] on
  /// itself or an ancestor.
  List<RouteBase> buildRoutes(RouteBuildContext context);

  /// Resolvers for notification payload types, keyed by `<name>.<event>`.
  Map<String, NotificationLocationResolver> get notificationRoutes => const {};
}

/// A route tree that breaks the routing conventions.
final class RouteConfigurationException implements Exception {
  /// Creates the exception with every [problems] found.
  const RouteConfigurationException(this.problems);

  /// Every problem found.
  final List<String> problems;

  @override
  String toString() =>
      'RouteConfigurationException:\n  - ${problems.join('\n  - ')}';
}

/// The routes of every module, validated and assembled.
///
/// Checks, for every module: a valid unique name; every `GoRoute` named
/// `<module>.<screen>` (unique across the app) with a conventional path;
/// every route covered by a [RouteAccess]; notification types prefixed with
/// the module name and unique. All problems are reported together in a
/// [RouteConfigurationException].
final class RouteRegistry {
  RouteRegistry._(this.routes, this.notificationResolvers);

  /// Validates and assembles [modules].
  factory RouteRegistry(
    List<RouteModule> modules, {
    required RouteBuildContext context,
  }) {
    final problems = <String>[];
    final moduleNames = <String>{};
    final routeNames = <String>{};
    final routes = <RouteBase>[];
    final resolvers = <String, NotificationLocationResolver>{};

    for (final module in modules) {
      final name = module.name;
      if (!RouteConventions.isModuleName(name)) {
        problems.add('module "$name" must be lowerCamelCase');
      }
      if (!moduleNames.add(name)) {
        problems.add('module "$name" is listed twice');
      }

      final moduleRoutes = module.buildRoutes(context);
      for (final route in moduleRoutes) {
        _check(
          route,
          module: name,
          absolute: true,
          covered: false,
          names: routeNames,
          problems: problems,
        );
      }
      routes.addAll(moduleRoutes);

      for (final MapEntry(key: type, value: resolver)
          in module.notificationRoutes.entries) {
        if (!RouteConventions.isRouteName(type) || !type.startsWith('$name.')) {
          problems.add('notification type "$type" must be "$name.<event>"');
        }
        if (resolvers.containsKey(type)) {
          problems.add('notification type "$type" is registered twice');
        }
        resolvers[type] = resolver;
      }
    }

    if (routes.isEmpty) problems.add('no routes are registered');
    if (problems.isNotEmpty) throw RouteConfigurationException(problems);
    return RouteRegistry._(
      List.unmodifiable(routes),
      Map.unmodifiable(resolvers),
    );
  }

  /// Every module's routes, in module order.
  final List<RouteBase> routes;

  /// Notification resolvers by payload type.
  final Map<String, NotificationLocationResolver> notificationResolvers;

  static void _check(
    RouteBase route, {
    required String module,
    required bool absolute,
    required bool covered,
    required Set<String> names,
    required List<String> problems,
  }) {
    final access = RouteAccess.fromMetadata(route.metadata);
    final isCovered = covered || access != null;
    if (access case AuthenticatedAccess(:final feature?)
        when !Env.featureFlagPattern.hasMatch(feature)) {
      problems.add(
        'feature "$feature" must be snake_case, as in FEATURE_FLAGS',
      );
    }
    switch (route) {
      case GoRoute(:final path, :final name):
        problems.addAll(
          RouteConventions.pathProblems(path, absolute: absolute),
        );
        if (name == null) {
          problems.add('route "$path" in module "$module" has no name');
        } else {
          if (!RouteConventions.isRouteName(name) ||
              !name.startsWith('$module.')) {
            problems.add('route name "$name" must be "$module.<screen>"');
          }
          if (!names.add(name)) {
            problems.add('route name "$name" is used twice');
          }
        }
        if (!isCovered) {
          problems.add('route "${name ?? path}" declares no RouteAccess');
        }
        for (final child in route.routes) {
          _check(
            child,
            module: module,
            absolute: false,
            covered: isCovered,
            names: names,
            problems: problems,
          );
        }
      case ShellRouteBase():
        // Shells add no path: their children keep the parent's position.
        for (final child in route.routes) {
          _check(
            child,
            module: module,
            absolute: absolute,
            covered: isCovered,
            names: names,
            problems: problems,
          );
        }
      default:
        problems.add('unsupported route type ${route.runtimeType}');
    }
  }
}
