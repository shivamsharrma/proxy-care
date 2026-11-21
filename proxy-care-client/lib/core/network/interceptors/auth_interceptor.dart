import 'package:dio/dio.dart';

import '../access_token_provider.dart';
import '../network_config.dart';
import '../public_endpoints.dart';
import '../request_options.dart';
import '../request_replay.dart';

/// Attaches the access token to Spring Boot API requests and recovers once
/// from a 401.
///
/// Request phase: adds `Authorization: Bearer <token>` from
/// [AccessTokenProvider] when there is a token, unless
/// * the request has `skipAuth` or its path is in [publicEndpoints], or
/// * the request goes to a different origin than [apiBaseUrl] (a token is
///   never sent to a third party).
///
/// Error phase, on a 401 to a request that carried a token: asks
/// [UnauthorizedRecovery] for a better token (a newer one the identity
/// provider already obtained, or a refreshed one) and replays the request
/// once with it. The replay is marked, so a second 401 is final; it goes
/// through the whole chain again, so it gets the newest token. A body that
/// cannot be sent twice (a consumed stream) is not replayed: the original
/// 401 stands.
///
/// It never refreshes, stores or decodes tokens itself, and never calls the
/// identity provider's SDK: the abstractions are implemented in
/// `core/auth`. Requests made by the Supabase SDK use the SDK's own HTTP
/// client and never pass through this interceptor.
final class AuthInterceptor extends Interceptor {
  /// Creates the interceptor. [dio] replays requests.
  AuthInterceptor({
    required this.tokens,
    required this.dio,
    required this.apiBaseUrl,
    this.recovery,
    this.publicEndpoints = const PublicEndpoints(),
  });

  /// Source of the current access token.
  final AccessTokenProvider tokens;

  /// Obtains a token after a 401; null disables recovery.
  final UnauthorizedRecovery? recovery;

  /// Replays requests.
  final Dio dio;

  /// The API's base URL: only requests to its origin get a token.
  final Uri apiBaseUrl;

  /// Paths that never get a token.
  final PublicEndpoints publicEndpoints;

  static const String _bearer = 'Bearer ';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_needsToken(options)) {
      options.headers.remove(ApiHeaders.authorization);
      handler.next(options);
      return;
    }
    final String? token;
    try {
      token = await tokens.getAccessToken();
    } on Object catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          message: 'Could not read the access token.',
        ),
      );
      return;
    }
    if (token != null && token.isNotEmpty) {
      options.headers[ApiHeaders.authorization] = '$_bearer$token';
    } else {
      // Missing token: send the request without one; the API decides.
      options.headers.remove(ApiHeaders.authorization);
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final rejected = _sentToken(options);
    final recovery = this.recovery;
    final eligible =
        err.response?.statusCode == 401 &&
        recovery != null &&
        rejected != null &&
        options.extra[RequestExtra.authRetried] != true &&
        _needsToken(options);
    if (!eligible) {
      handler.next(err);
      return;
    }

    final String? token;
    try {
      token = await recovery.recoverAccessToken(rejectedToken: rejected);
    } on Object {
      // Recovery failed; the session layer has already updated the
      // authentication state. The original 401 stands.
      handler.next(err);
      return;
    }
    if (token == null || token.isEmpty || token == rejected) {
      handler.next(err);
      return;
    }
    if (!prepareForReplay(options)) {
      handler.next(err);
      return;
    }

    options.extra[RequestExtra.authRetried] = true;
    try {
      // The replay runs the whole chain; onRequest attaches the newest
      // token from the provider.
      handler.resolve(await dio.fetch<Object?>(options));
    } on DioException catch (replayError) {
      handler.next(replayError);
    }
  }

  bool _needsToken(RequestOptions options) =>
      options.extra[RequestExtra.skipAuth] != true &&
      !publicEndpoints.contains(options.uri.path) &&
      _sameOrigin(options.uri);

  bool _sameOrigin(Uri uri) =>
      uri.scheme == apiBaseUrl.scheme &&
      uri.host == apiBaseUrl.host &&
      uri.port == apiBaseUrl.port;

  static String? _sentToken(RequestOptions options) {
    final header = options.headers[ApiHeaders.authorization];
    return header is String && header.startsWith(_bearer)
        ? header.substring(_bearer.length)
        : null;
  }
}
