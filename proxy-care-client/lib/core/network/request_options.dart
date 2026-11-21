import 'package:dio/dio.dart';

/// Per-request retry behaviour (see `RetryInterceptor`).
final class RetryPolicy {
  /// Creates a retry policy.
  const RetryPolicy({this.enabled = true, this.maxRetries});

  /// Never retry this request.
  static const RetryPolicy never = RetryPolicy(enabled: false);

  /// Retry this request even if its method is not GET. Use only for an
  /// operation that is safe to repeat (for example a write sent with an
  /// idempotency key).
  static const RetryPolicy always = RetryPolicy();

  /// Whether the request may be retried.
  final bool enabled;

  /// Overrides the default number of retries.
  final int? maxRetries;
}

/// Cancels in-flight requests, for example when a screen is closed.
///
/// Pass the same instance to several requests to cancel them together. A
/// cancelled request fails with `CancelledException`.
final class RequestCancellation {
  /// Creates a cancellation handle.
  RequestCancellation();

  final CancelToken _token = CancelToken();

  /// Cancels every request using this handle.
  void cancel([String reason = 'Cancelled by the app']) =>
      _token.cancel(reason);

  /// Whether [cancel] was called.
  bool get isCancelled => _token.isCancelled;
}

/// Gives the networking layer access to the Dio token behind a
/// [RequestCancellation]. Not exported to features.
extension RequestCancellationToken on RequestCancellation {
  /// The underlying token.
  CancelToken get cancelToken => _token;
}

/// Request-specific settings. Every field is optional.
final class ApiRequestOptions {
  /// Creates request options.
  const ApiRequestOptions({
    this.headers = const {},
    this.receiveTimeout,
    this.sendTimeout,
    this.cancellation,
    this.retry,
    this.idempotencyKey,
    this.ifMatch,
    this.skipAuth = false,
  });

  /// Extra headers for this request.
  final Map<String, String> headers;

  /// Overrides the receive timeout.
  final Duration? receiveTimeout;

  /// Overrides the send timeout (requests with a body).
  final Duration? sendTimeout;

  /// Cancels the request.
  final RequestCancellation? cancellation;

  /// Overrides the default retry behaviour (GET only).
  final RetryPolicy? retry;

  /// Sent as the `Idempotency-Key` header. Generate one per logical
  /// operation (`IdempotencyKey.generate()`) and reuse it when the user
  /// repeats the same operation.
  final String? idempotencyKey;

  /// Sent as the `If-Match` header: the `ETag` of the version being
  /// updated (`ApiResponse.etag` from the read, stored unchanged), or `*`.
  /// Updates to versioned resources require it (ADR 0012): without it the
  /// backend answers 428, with a stale one 412.
  final String? ifMatch;

  /// Sends the request without an access token and keeps
  /// `AuthInterceptor` out of it (sign-in, token refresh).
  final bool skipAuth;
}

/// Keys of `RequestOptions.extra` that carry client metadata through the
/// interceptor chain. They travel with the request, so a retry of the same
/// logical request keeps them.
abstract final class RequestExtra {
  /// `bool`: skip `AuthInterceptor`.
  static const String skipAuth = 'pc.skipAuth';

  /// `RetryPolicy`: request-specific retry behaviour.
  static const String retryPolicy = 'pc.retryPolicy';

  /// `bool`: the request is a retry dispatched by `RetryInterceptor`; no
  /// interceptor may start another retry loop for it.
  static const String isRetry = 'pc.isRetry';

  /// `int`: how many retries have been dispatched so far.
  static const String retryCount = 'pc.retryCount';

  /// `bool`: the request was already repeated after a token refresh.
  static const String authRetried = 'pc.authRetried';

  /// `String`: correlation ID of the logical request.
  static const String correlationId = 'pc.correlationId';

  /// `DateTime`: when the current attempt was handed to the adapter.
  static const String startedAt = 'pc.startedAt';
}
