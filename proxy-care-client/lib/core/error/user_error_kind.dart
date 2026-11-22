import 'failure.dart';

/// The categories of user-facing error message (one localized message
/// each). The single place that decides which message a failure shows.
///
/// Pure Dart; the localized text is looked up in `core/l10n`.
enum UserErrorKind {
  /// The server could not be reached.
  network,

  /// The request timed out (client timeout, HTTP 408 / 504).
  timeout,

  /// HTTP 401 (`UNAUTHENTICATED`).
  unauthenticated,

  /// HTTP 403 (`ACCESS_DENIED`).
  forbidden,

  /// HTTP 404 (`RESOURCE_NOT_FOUND`, `PROFILE_NOT_FOUND`).
  notFound,

  /// HTTP 400 (`VALIDATION_FAILED`; `MALFORMED_REQUEST`: unreadable body
  /// or a missing or mistyped parameter; `INVALID_PARAMETER`: HTTP method
  /// not supported) or a 4xx with field errors.
  validation,

  /// HTTP 409 (`CONCURRENT_MODIFICATION`, `RESOURCE_ALREADY_EXISTS`).
  conflict,

  /// HTTP 422 (`BUSINESS_RULE_VIOLATION` or a feature code).
  businessRule,

  /// HTTP 429 (no backend code; not sent today).
  rateLimited,

  /// Other server errors (`INTERNAL_ERROR`, `EXTERNAL_SERVICE_ERROR`,
  /// an unreadable response).
  server,

  /// HTTP 503 (`EXTERNAL_SERVICE_UNAVAILABLE`).
  serviceUnavailable,

  /// Anything the app could not classify.
  unknown;

  /// The message category for [failure], or null for a cancelled operation
  /// (nothing to tell the user).
  ///
  /// A feature [DomainFailure] shows the business-rule message unless the
  /// feature gives it a dedicated one.
  static UserErrorKind? of(AppFailure failure) => switch (failure) {
    NetworkFailure(isTimeout: true) => timeout,
    NetworkFailure() => network,
    UnauthorizedFailure() => unauthenticated,
    ForbiddenFailure() => forbidden,
    NotFoundFailure() => notFound,
    ValidationFailure() => validation,
    ConflictFailure() => conflict,
    BusinessRuleFailure() => businessRule,
    DomainFailure() => businessRule,
    RateLimitedFailure() => rateLimited,
    ServerFailure() => server,
    ServiceUnavailableFailure() => serviceUnavailable,
    CancelledFailure() => null,
    UnexpectedFailure() => unknown,
  };
}
