/// Naming rules for routes, paths, parameters and notification types.
///
/// Every route registered with the router is checked against these rules
/// when the router is built (see `RouteRegistry`), so a misnamed route fails
/// at start-up and in tests instead of at navigation time. Pure Dart.
abstract final class RouteConventions {
  /// A route module (feature) name: lowerCamelCase, for example `bookings`.
  static final RegExp moduleName = RegExp(r'^[a-z][a-zA-Z0-9]*$');

  /// A route name: `<module>.<screen>[.<subScreen>…]`, each part
  /// lowerCamelCase, for example `bookings.detail` or
  /// `bookings.detail.edit`. Notification payload types use the same shape.
  static final RegExp routeName = RegExp(
    r'^[a-z][a-zA-Z0-9]*(\.[a-z][a-zA-Z0-9]*)+$',
  );

  /// One path segment: lowercase kebab-case words, a `:lowerCamelCase`
  /// parameter, or `_` (reserved for the router's own internal routes).
  static final RegExp pathSegment = RegExp(
    r'^(_|[a-z0-9]+(-[a-z0-9]+)*|:[a-z][a-zA-Z0-9]*)$',
  );

  /// A query parameter or payload data key: lowerCamelCase.
  static final RegExp queryKey = RegExp(r'^[a-z][a-zA-Z0-9]*$');

  /// Whether [name] is a valid module name.
  static bool isModuleName(String name) => moduleName.hasMatch(name);

  /// Whether [name] is a valid route name (or notification payload type).
  static bool isRouteName(String name) => routeName.hasMatch(name);

  /// Whether [key] is a valid query parameter key.
  static bool isQueryKey(String key) => queryKey.hasMatch(key);

  /// Problems with the route [path]; empty when it follows the conventions.
  ///
  /// Top-level routes (and the direct children of a top-level shell) use an
  /// [absolute] path that starts with `/`; nested routes use a relative path
  /// without a leading or trailing `/`.
  static List<String> pathProblems(String path, {required bool absolute}) {
    if (absolute) {
      if (!path.startsWith('/')) {
        return ['"$path" must start with "/" (it is a top-level route)'];
      }
      if (path == '/') return const [];
      path = path.substring(1);
    } else if (path.startsWith('/')) {
      return ['"$path" is nested, so it must not start with "/"'];
    }
    return [
      for (final segment in path.split('/'))
        if (!pathSegment.hasMatch(segment))
          '"$segment" in "$path" must be kebab-case or a :camelCase parameter',
    ];
  }
}

/// Query parameter keys the router itself reads. Features must not use them.
abstract final class RouterQueryKeys {
  /// The location a redirect interrupted, restored after the guard passes.
  static const from = 'from';

  /// Why the router redirected, for example
  /// [RouterRedirectReason.sessionExpired].
  static const reason = 'reason';

  /// Every reserved key.
  static const reserved = {from, reason};
}

/// Values of the [RouterQueryKeys.reason] query parameter.
abstract final class RouterRedirectReason {
  /// The session ended without the user signing out.
  static const sessionExpired = 'sessionExpired';
}
