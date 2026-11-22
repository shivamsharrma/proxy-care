# core/network

The HTTP layer, built on Dio. See ARCHITECTURE.md, "Networking".

- `api_client.dart`: `ApiClient`, the only API the data layer uses (GET,
  POST, PUT, PATCH, DELETE, multipart upload, download). Throws only
  `AppException`s.
- `dio_api_client.dart`: the Dio implementation; maps Dio errors with
  `ErrorMapper`.
- `dio_factory.dart`: `BaseOptions` (`<API_BASE_URL>/api/v1/`, 10 / 30 /
  30 s timeouts, JSON) and the interceptor order.
- `interceptors/`: correlation ID, logging (with `Redactor` from `core/security`), auth,
  retry.
- `response_parser.dart`, `api_response.dart`: typed parsing of bare JSON
  bodies and `PageResponse` pages (`pageDecoder`); response headers
  (`ETag`, `Location`).
- `request_options.dart`: per-request headers, timeouts, cancellation,
  retry policy, idempotency key, `If-Match` (idempotency and `If-Match` are
  not enforced by the backend today; a version clash is 409
  `CONCURRENT_MODIFICATION`), `skipAuth`.
- `access_token_provider.dart`: `AccessTokenProvider` and
  `UnauthorizedRecovery`, the only authentication abstractions the
  interceptor knows (implemented in `core/auth`); `public_endpoints.dart`;
  `request_replay.dart` (which bodies may be sent twice).
- `pagination.dart`, `transfer.dart`, `idempotency_key.dart`,
  `network_config.dart`.

Rules:

- Dio types stay in this folder and in `core/di/network_providers.dart`;
  domain and presentation never import them (architecture test).
- Nothing here knows about a feature or an endpoint.
- Never log tokens, bodies or personal data.
