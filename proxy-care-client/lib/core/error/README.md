# core/error

Centralized error handling. See ARCHITECTURE.md, "Errors".

- `app_exception.dart`: sealed infrastructure exceptions (`AppException`).
  Core and data only.
- `failure.dart`: sealed application failures (`AppFailure`) and the
  `DomainFailure` base for business rules. Pure Dart; the domain uses it.
- `failure_mapper.dart`: `AppException.toFailure()`.
- `error_mapper.dart`: `ErrorMapper` (Dio, HTTP status, RFC 9457 problem
  details, `Retry-After`, serialization, unknown), `BackendError`,
  `BackendErrorParser` and `parseRetryAfter`.
- `backend_error_code.dart`: the backend error codes (ADR 0012).
- `user_error_kind.dart`: which user-facing message a failure shows (text in
  `core/l10n`).
- `crash_reporter.dart`: vendor-independent `CrashReporter`, privacy-safe
  `CrashReport`, `NoopCrashReporter`.
- `repository_guard.dart`: `guardResult`, the repository convention.
- `serialization.dart`: `decodeResponse` for parsing response bodies.
- `error_reporter.dart`, `logger_error_reporter.dart`: where unhandled errors
  go.
- `global_error_handlers.dart`, `error_widget_builder.dart`: framework,
  platform and zone handlers, and the failed-widget fallback.
