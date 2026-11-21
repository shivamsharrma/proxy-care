import 'route_conventions.dart';

/// Preserves the location a guard interrupted, so the user can continue
/// there afterwards. Pure Dart.
///
/// The interrupted location travels in the [RouterQueryKeys.from] query
/// parameter of the redirect target (for example
/// `/sign-in?from=%2Fbookings%2F42`). It survives a cold start, a reload on
/// web and process death because it is part of the URL. Every value read
/// back is [sanitize]d, so a crafted link can never send the user to
/// another site.
abstract final class IntendedDestination {
  /// The longest location accepted.
  static const maxLength = 2048;

  /// [raw] as a safe in-app location (path and query, no fragment), or null
  /// when it is not one: empty, too long, not starting with a single `/`,
  /// containing a scheme, host, backslash or `.`/`..` segment.
  static String? sanitize(String? raw) {
    if (raw == null || raw.isEmpty || raw.length > maxLength) return null;
    if (!raw.startsWith('/') || raw.startsWith('//') || raw.contains(r'\')) {
      return null;
    }
    // Checked on the raw text: Uri.parse would silently resolve `..`.
    final rawPath = raw.split(RegExp('[?#]')).first;
    if (rawPath
        .split('/')
        .any((segment) => segment == '.' || segment == '..')) {
      return null;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
    return locationOf(uri);
  }

  /// The intended destination carried by [uri], if any and if safe.
  static String? of(Uri uri) =>
      sanitize(uri.queryParameters[RouterQueryKeys.from]);

  /// [target] with [intended] (and an optional [reason]) added as query
  /// parameters. Existing query parameters of [target] are kept.
  static String attach(
    String target, {
    required String intended,
    String? reason,
  }) {
    final uri = Uri.parse(target);
    return locationOf(
      uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          RouterQueryKeys.from: intended,
          RouterQueryKeys.reason: ?reason,
        },
      ),
    );
  }

  /// The path and query of [uri], without scheme, host or fragment.
  static String locationOf(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    return uri.query.isEmpty ? path : '$path?${uri.query}';
  }
}
