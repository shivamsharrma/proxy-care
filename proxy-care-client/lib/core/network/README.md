# core/network

The HTTP layer, built on Dio. Data sources declare their calls as Retrofit
interfaces over the Dio from `dioProvider`. See ARCHITECTURE.md,
"Networking".

- `dio_factory.dart`: `BaseOptions` (`<API_BASE_URL>/api/v1/`, 10 / 30 /
  30 s timeouts, JSON), no send timeout without a body, and the interceptor
  order.
- `interceptors/`: correlation ID, logging (one line per attempt, no
  headers, query or bodies), auth (bearer token only).
- Retry is `dio_smart_retry`, configured in `dio_factory.dart`: GET only, on
  connection errors, timeouts and 502 / 503 / 504; `network_config.dart`
  holds the retry count and delays.
- `invalid_response_logger.dart`: `InvalidResponseLogger`, the `errorLogger`
  of every Retrofit API class; a body that does not match its DTO becomes
  `ServerException.invalidResponse`.
- `request_options.dart`: `RequestExtra` keys (`skipAuth`, set with
  Retrofit's `@Extra`).
- `access_token_provider.dart`: `AccessTokenProvider`, the only
  authentication abstraction the interceptor knows (implemented in
  `core/auth`); `public_endpoints.dart`.
- `pagination.dart`: `PageRequest` and `PageResponse<T>` (decoded by Retrofit
  through `PageResponse.fromJson`).
- `idempotency_key.dart`, `network_config.dart` (constants and
  `ApiHeaders`).

Rules:

- Dio types stay in this folder, in `core/di/network_providers.dart` and in
  the data layer's Retrofit API files; domain and presentation never import
  Dio or Retrofit (architecture test).
- Nothing here knows about a feature or an endpoint.
- Never log tokens, bodies or personal data.
