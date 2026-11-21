import 'package:dio/dio.dart';

import 'access_token_provider.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/correlation_id_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'network_config.dart';
import 'public_endpoints.dart';

/// Builds the app's configured [Dio].
///
/// Interceptor order (Dio runs request, response **and** error interceptors
/// in the order they were added; verified by `dio_factory_test.dart`):
///
/// 1. `ImplyContentTypeInterceptor` (Dio's own, always first).
/// 2. [CorrelationIdInterceptor]: every attempt, including the first, has
///    its ID before anything logs it.
/// 3. [LoggingInterceptor]: starts the timer, and in the error phase logs
///    every failed attempt (including the 401 that triggers a refresh)
///    before recovery is tried.
/// 4. [AuthInterceptor]: attaches the token just before transmission; on a
///    401, obtains a better token through [UnauthorizedRecovery] and replays
///    the request once.
/// 5. [RetryInterceptor]: last, so it sees only failures the earlier
///    interceptors did not recover from.
///
/// Repeats from 4 and retries from 5 run through the whole chain again (new
/// token, new log line, same correlation ID) and are marked so they cannot
/// start further loops. Errors are mapped to `AppException`s once, by
/// `DioApiClient`, after the chain.
final class DioFactory {
  /// Creates a factory.
  const DioFactory({
    required this.baseUrl,
    required this.tokens,
    required this.log,
    this.recovery,
    this.publicEndpoints = const PublicEndpoints(),
    this.detailedLogging = false,
    this.adapter,
    this.retryDelay,
  });

  /// The environment's API base URL (`API_BASE_URL`, the host). Requests
  /// go to [NetworkConfig.apiRoot] of it (`<baseUrl>/api/v1/`).
  final Uri baseUrl;

  /// Supplies the access token.
  final AccessTokenProvider tokens;

  /// Obtains a token after a 401; null disables recovery.
  final UnauthorizedRecovery? recovery;

  /// Paths that never get a token.
  final PublicEndpoints publicEndpoints;

  /// Where request log lines go.
  final void Function(String message) log;

  /// Detailed (masked) request logging; debug builds only.
  final bool detailedLogging;

  /// Replaces the platform HTTP adapter (tests).
  final HttpClientAdapter? adapter;

  /// Replaces the retry backoff wait (tests).
  final RetryDelay? retryDelay;

  /// The base options for [baseUrl]: the `/api/v1` root, timeouts, JSON
  /// content type and the default headers.
  static BaseOptions baseOptions(Uri baseUrl) => BaseOptions(
    baseUrl: NetworkConfig.apiRoot(baseUrl).toString(),
    connectTimeout: NetworkConfig.connectTimeout,
    receiveTimeout: NetworkConfig.receiveTimeout,
    sendTimeout: NetworkConfig.sendTimeout,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    headers: {ApiHeaders.accept: ApiHeaders.acceptJson},
  );

  /// Creates a configured [Dio].
  Dio create() {
    final dio = Dio(baseOptions(baseUrl));
    if (adapter case final adapter?) dio.httpClientAdapter = adapter;
    dio.interceptors.addAll([
      CorrelationIdInterceptor(),
      LoggingInterceptor(log: log, detailed: detailedLogging),
      AuthInterceptor(
        tokens: tokens,
        recovery: recovery,
        dio: dio,
        apiBaseUrl: baseUrl,
        publicEndpoints: publicEndpoints,
      ),
      RetryInterceptor(dio: dio, delay: retryDelay),
    ]);
    return dio;
  }
}
