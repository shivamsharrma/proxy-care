import 'failure.dart';

/// The categories of user-facing error message (one localized message
/// each). The single place that decides which message a failure shows.
///
/// Pure Dart; the localized text is looked up in `core/l10n`.
enum UserErrorKind {
  /// NETWORK_ERROR.
  network,

  /// TIMEOUT.
  timeout,

  /// UNAUTHENTICATED.
  unauthenticated,

  /// FORBIDDEN.
  forbidden,

  /// NOT_FOUND.
  notFound,

  /// VALIDATION_ERROR.
  validation,

  /// CONFLICT.
  conflict,

  /// BUSINESS_RULE_VIOLATION.
  businessRule,

  /// RATE_LIMITED.
  rateLimited,

  /// SERVER_ERROR.
  server,

  /// SERVICE_UNAVAILABLE.
  serviceUnavailable,

  /// UNKNOWN_ERROR.
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
