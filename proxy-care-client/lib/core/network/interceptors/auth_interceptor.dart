import 'package:dio/dio.dart';

import '../access_token_provider.dart';
import '../network_config.dart';
import '../public_endpoints.dart';
import '../request_options.dart';

/// Attaches the access token to Spring Boot API requests.
///
/// Adds `Authorization: Bearer <token>` from [AccessTokenProvider] when
/// there is a token, unless the request has `skipAuth` or its path is in
/// [publicEndpoints]. A request without a token is sent without the header;
/// the API decides. A 401 is not recovered or repeated here: it reaches the
/// caller, and the identity provider's SDK refreshes tokens before they
/// expire.
///
/// It never refreshes, stores or decodes tokens itself, and never calls the
/// identity provider's SDK: the abstraction is implemented in `core/auth`.
/// Requests made by the Supabase SDK use the SDK's own HTTP client and never
/// pass through this interceptor.
final class AuthInterceptor extends Interceptor {
  /// Creates the interceptor.
  AuthInterceptor({
    required this.tokens,
    this.publicEndpoints = const PublicEndpoints(),
  });

  /// Source of the current access token.
  final AccessTokenProvider tokens;

  /// Paths that never get a token.
  final PublicEndpoints publicEndpoints;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers.remove(ApiHeaders.authorization);
    if (!_needsToken(options)) {
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
      options.headers[ApiHeaders.authorization] = 'Bearer $token';
    }
    handler.next(options);
  }

  bool _needsToken(RequestOptions options) =>
      options.extra[RequestExtra.skipAuth] != true &&
      !publicEndpoints.contains(options.uri.path);
}
