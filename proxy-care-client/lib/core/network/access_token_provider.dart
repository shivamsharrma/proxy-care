/// Supplies the access token that `AuthInterceptor` attaches to API
/// requests. The networking layer knows nothing else about authentication:
/// it never stores, refreshes or decodes tokens itself.
abstract interface class AccessTokenProvider {
  /// The latest available access token, or null when signed out.
  Future<String?> getAccessToken();
}

/// Recovers an access token after the API rejected [rejectedToken] with a
/// 401, so `AuthInterceptor` can replay the request once.
///
/// The implementation (in `core/auth`) first reuses a newer token if the
/// identity provider already refreshed, and otherwise asks it to refresh.
/// It returns null when no better token can be obtained; the 401 then
/// stands.
abstract interface class UnauthorizedRecovery {
  /// A token to replay the request with, or null.
  Future<String?> recoverAccessToken({required String rejectedToken});
}

/// No token: used when authentication is not configured.
final class NoAccessTokenProvider
    implements AccessTokenProvider, UnauthorizedRecovery {
  /// Creates a provider that never has a token.
  const NoAccessTokenProvider();

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> recoverAccessToken({required String rejectedToken}) async =>
      null;
}
