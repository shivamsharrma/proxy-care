import 'package:dio/dio.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

import 'access_token_provider.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/correlation_id_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'network_config.dart';
import 'public_endpoints.dart';

/// Builds the app's configured [Dio].
///
/// Interceptor order (Dio runs request, response **and** error interceptors
/// in the order they were added; verified by `dio_factory_test.dart`):
///
/// 1. `ImplyContentTypeInterceptor` (Dio's own, always first).
/// 2. A request without a body gets no send timeout (an inline interceptor).
/// 3. [CorrelationIdInterceptor]: the request has its ID before anything
///    logs it.
/// 4. [LoggingInterceptor]: starts the timer, and logs the outcome.
/// 5. [AuthInterceptor]: attaches the token just before transmission.
/// 6. `RetryInterceptor` (`dio_smart_retry`): retries a failed **GET** up to
///    [NetworkConfig.maxRetries] times, only for connection problems,
///    timeouts and HTTP 502, 503 and 504. Other methods are never retried,
///    because the backend does not enforce idempotency keys. A retry runs
///    through the whole chain again (new log line, same correlation ID).
///
/// Errors leave the chain as `DioException`s; `guardResult` maps them to
/// `AppException`s with `ErrorMapper`.
final class DioFactory {
  /// Creates a factory.
  const DioFactory({
    required this.baseUrl,
    required this.tokens,
    required this.log,
    this.publicEndpoints = const PublicEndpoints(),
    this.adapter,
    this.retryDelays = NetworkConfig.retryDelays,
  });

  /// The environment's API base URL (`API_BASE_URL`, the host). Requests
  /// go to [NetworkConfig.apiRoot] of it (`<baseUrl>/api/v1/`).
  final Uri baseUrl;

  /// Supplies the access token.
  final AccessTokenProvider tokens;

  /// Paths that never get a token.
  final PublicEndpoints publicEndpoints;

  /// Where request log lines go.
  final void Function(String message) log;

  /// Replaces the platform HTTP adapter (tests).
  final HttpClientAdapter? adapter;

  /// The waits before each retry; tests pass an empty list so they do not
  /// sleep.
  final List<Duration> retryDelays;

  /// The base options for [baseUrl]: the `/api/v1` root, timeouts, JSON
  /// content type and the default headers.
  static BaseOptions baseOptions(Uri baseUrl) => BaseOptions(
    baseUrl: NetworkConfig.apiRoot(baseUrl).toString(),
    connectTimeout: NetworkConfig.connectTimeout,
    receiveTimeout: NetworkConfig.receiveTimeout,
    sendTimeout: NetworkConfig.sendTimeout,
    contentType: Headers.jsonContentType,
    responseType: ResponseType.json,
    headers: {ApiHeaders.accept: ApiHeaders.json},
  );

  /// Creates a configured [Dio].
  Dio create() {
    final dio = Dio(baseOptions(baseUrl));
    if (adapter case final adapter?) dio.httpClientAdapter = adapter;
    dio.interceptors.addAll([
      // Without a body there is nothing to time out on, and on web Dio warns
      // when a send timeout is set on a bodiless request.
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.data == null) options.sendTimeout = Duration.zero;
          handler.next(options);
        },
      ),
      CorrelationIdInterceptor(),
      LoggingInterceptor(log: log),
      AuthInterceptor(tokens: tokens, publicEndpoints: publicEndpoints),
      RetryInterceptor(
        dio: dio,
        retries: NetworkConfig.maxRetries,
        retryDelays: retryDelays,
        retryEvaluator: _retryGetOnTransientFailure,
      ),
    ]);
    return dio;
  }
}

final _transientFailures = DefaultRetryEvaluator({502, 503, 504});

bool _retryGetOnTransientFailure(DioException error, int attempt) =>
    error.requestOptions.method == 'GET' &&
    _transientFailures.evaluate(error, attempt) as bool;
