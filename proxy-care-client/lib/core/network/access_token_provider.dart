/// Supplies the access token that `AuthInterceptor` attaches to API
/// requests. The networking layer knows nothing else about authentication:
/// it never stores, refreshes or decodes tokens itself.
abstract interface class AccessTokenProvider {
  /// The latest available access token, or null when signed out.
  Future<String?> getAccessToken();
}
