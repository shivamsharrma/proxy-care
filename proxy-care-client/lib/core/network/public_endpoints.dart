/// API paths that are called without an access token (for example health
/// or public configuration endpoints). Matched on the full request path,
/// including the `/api/v1` prefix (`NetworkConfig.apiBasePath`), as exact
/// paths or prefixes ending in `/`.
///
/// Requests can also opt out one by one with `ApiRequestOptions.skipAuth`.
/// The list is empty: no public Spring Boot endpoint is defined yet.
final class PublicEndpoints {
  /// Creates a list of public [paths].
  const PublicEndpoints([this.paths = const []]);

  /// Exact paths (`/api/v1/status`) or prefixes ending in `/`
  /// (`/api/v1/public/`).
  final List<String> paths;

  /// Whether [path] needs no token.
  bool contains(String path) => paths.any(
    (pattern) =>
        pattern.endsWith('/') ? path.startsWith(pattern) : path == pattern,
  );
}
