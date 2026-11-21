import 'dart:math' as math;

import 'package:dio/dio.dart';

import '../../error/error_mapper.dart';
import '../network_config.dart';
import '../request_options.dart';
import '../request_replay.dart';

/// Waits for [delay]; injectable so tests do not sleep.
typedef RetryDelay = Future<void> Function(Duration delay);

/// Retries requests that failed for a transient reason.
///
/// Retried by default: **GET** requests that failed with a connection
/// error or connection timeout, or with HTTP **502, 503 or 504**, and a
/// **429** that carries `Retry-After`. Up to [maxRetries] retries, with
/// exponential backoff ([baseDelay], doubling).
///
/// `Retry-After` (seconds, on 429 and 503) is honoured: the wait before the
/// retry is at least that long. A `Retry-After` longer than
/// [maxRetryAfter] is not waited out: the error goes to the caller, whose
/// exception carries it (`ServerException.retryAfter`). A 429 without
/// `Retry-After` is not retried.
///
/// Never retried: cancelled requests, 401 and 403 (and every other status),
/// other methods (POST, PUT, PATCH, DELETE are not idempotent by default),
/// requests whose body cannot be sent twice, and requests whose
/// `RetryPolicy` is disabled. Authentication recovery is
/// `AuthInterceptor`'s job, never a retry. A request with
/// `RetryPolicy(enabled: true)` is retried whatever its method (use it only
/// with an idempotency key).
///
/// The retry loop lives in the first chain that sees the failure. Each
/// retry is dispatched through the whole chain again (so it gets a fresh
/// token and is logged) but is marked as a retry, so no interceptor in the
/// nested chain starts a second loop.
final class RetryInterceptor extends Interceptor {
  /// Creates the interceptor. [dio] dispatches the retries.
  RetryInterceptor({
    required this.dio,
    this.maxRetries = NetworkConfig.maxRetries,
    this.baseDelay = NetworkConfig.retryBaseDelay,
    this.maxRetryAfter = NetworkConfig.maxRetryAfter,
    RetryDelay? delay,
  }) : _delay = delay ?? Future<void>.delayed;

  final RetryDelay _delay;

  /// Dispatches the retries.
  final Dio dio;

  /// Default number of retries after the first attempt.
  final int maxRetries;

  /// Delay before the first retry.
  final Duration baseDelay;

  /// The longest `Retry-After` this interceptor waits out.
  final Duration maxRetryAfter;

  static const Set<int> _retryableStatuses = {429, 502, 503, 504};

  /// The delay before retry number [retry] (1-based).
  Duration backoff(int retry) => baseDelay * math.pow(2, retry - 1).toInt();

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    // A retry's failure is returned to the loop that dispatched it.
    if (options.extra[RequestExtra.isRetry] == true) {
      handler.next(err);
      return;
    }

    final policy = options.extra[RequestExtra.retryPolicy] as RetryPolicy?;
    final limit = policy?.maxRetries ?? maxRetries;
    var error = err;
    var retry = 0;
    while (retry < limit) {
      final wait = _waitBeforeRetry(error, policy, retry + 1);
      if (wait == null) break;
      retry++;
      await _delay(wait);
      options.extra[RequestExtra.isRetry] = true;
      options.extra[RequestExtra.retryCount] = retry;
      // A body that cannot be sent twice ends the loop with the last error.
      if (!prepareForReplay(options)) break;
      try {
        final response = await dio.fetch<Object?>(options);
        options.extra.remove(RequestExtra.isRetry);
        handler.resolve(response);
        return;
      } on DioException catch (retryError) {
        error = retryError;
      }
    }
    options.extra.remove(RequestExtra.isRetry);
    handler.next(error);
  }

  /// How long to wait before retry number [retry] of the request that
  /// failed with [error], or null if it must not be retried.
  Duration? _waitBeforeRetry(
    DioException error,
    RetryPolicy? policy,
    int retry,
  ) {
    if (!_shouldRetry(error, policy)) return null;
    final delay = backoff(retry);
    final status = error.response?.statusCode;
    if (status != 429 && status != 503) return delay;

    final retryAfter = parseRetryAfter(
      error.response?.headers[ApiHeaders.retryAfter]?.firstOrNull,
    );
    if (retryAfter == null) return status == 429 ? null : delay;
    if (retryAfter > maxRetryAfter) return null;
    return retryAfter > delay ? retryAfter : delay;
  }

  bool _shouldRetry(DioException error, RetryPolicy? policy) {
    if (error.type == DioExceptionType.cancel) return false;
    if (error.requestOptions.cancelToken?.isCancelled ?? false) return false;
    if (policy != null && !policy.enabled) return false;
    final idempotent = error.requestOptions.method.toUpperCase() == 'GET';
    if (!idempotent && policy == null) return false;

    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.badResponse => _retryableStatuses.contains(
        error.response?.statusCode,
      ),
      _ => false,
    };
  }
}
