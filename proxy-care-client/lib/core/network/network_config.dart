/// Fixed networking settings shared by every request.
abstract final class NetworkConfig {
  /// Path prefix of every Spring Boot API endpoint (`/api/v1`, see
  /// `.claude/rules/backend-code.md` → API).
  ///
  /// `API_BASE_URL` stays the host (plus any reverse-proxy prefix); the
  /// prefix is appended once, by `DioFactory` ([apiRoot]), so data sources
  /// pass resource paths only (`/patients/p1`, not `/api/v1/patients/p1`).
  static const String apiBasePath = '/api/v1';

  /// The URL resource paths are resolved against: [apiBaseUrl] with
  /// [apiBasePath] appended and a trailing `/`, for example
  /// `https://api.proxycare.in/api/v1/`.
  ///
  /// Dio joins its base URL and a request path as strings and collapses a
  /// doubled `/`, so with the trailing slash both `/patients` and `patients`
  /// resolve under the prefix. An absolute request URL (another origin)
  /// ignores it.
  static Uri apiRoot(Uri apiBaseUrl) {
    final host = apiBaseUrl.path.replaceFirst(RegExp(r'/+$'), '');
    return apiBaseUrl.replace(path: '$host$apiBasePath/');
  }

  /// Time allowed to open a connection.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Time allowed between response bytes.
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Time allowed to send the request body. Applied only to requests that
  /// have a body: on web, Dio warns when a send timeout is set on a request
  /// without one.
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Retries after the first attempt (see `RetryInterceptor`).
  static const int maxRetries = 3;

  /// Delay before the first retry; doubled for each further retry
  /// (0.5 s, 1 s, 2 s).
  static const Duration retryBaseDelay = Duration(milliseconds: 500);

  /// The longest `Retry-After` (429 / 503) that `RetryInterceptor` waits
  /// out by itself. The backend sends no `Retry-After` today. A longer one is not retried automatically: the error
  /// reaches the caller with its `retryAfter`, so the screen can say when
  /// to try again instead of hanging.
  static const Duration maxRetryAfter = Duration(seconds: 10);
}

/// HTTP header names and media types used by the client.
abstract final class ApiHeaders {
  /// Bearer token.
  static const String authorization = 'Authorization';

  /// Identifies one logical request across the client, retries and the
  /// client logs. The backend identifies the request in its own logs by
  /// the error's `meta.traceId` (`AppException.traceId`).
  static const String correlationId = 'X-Correlation-Id';

  /// Makes a write safe to repeat. Not enforced by the backend today: it
  /// has no Idempotency-Key filter.
  static const String idempotencyKey = 'Idempotency-Key';

  /// Sends the `ETag` of the version being updated. Not enforced by the
  /// backend today: it reads no `If-Match` and reports a version clash as
  /// 409 `CONCURRENT_MODIFICATION`.
  static const String ifMatch = 'If-Match';

  /// Version of a versioned resource. The backend sends none today.
  static const String etag = 'ETag';

  /// Path of a created resource (201 Created).
  static const String location = 'Location';

  /// Seconds to wait before trying again (429, 503). The backend sends
  /// none today.
  static const String retryAfter = 'Retry-After';

  /// Media types the client accepts.
  static const String accept = 'Accept';

  /// JSON media type: the backend's success bodies and `ApiError`s. Sent
  /// as the `Accept` value of every request.
  static const String json = 'application/json';
}
