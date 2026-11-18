/// The backend's standard error codes: the `code` member of a problem
/// details error response (ADR 0012). Stable, machine-readable
/// identifiers: error handling and localized messages may branch on them,
/// never on the problem's `title` or `detail`.
///
/// HTTP status codes stay authoritative for transport-level classification;
/// a code only refines what the status leaves open (for example a 422 that
/// is a business-rule violation rather than invalid input). The backend
/// may add codes: an unknown code is kept as a raw string and the error is
/// classified by its HTTP status.
///
/// Pure Dart: failures carry it into the domain and presentation layers.
enum BackendErrorCode {
  /// Unreadable JSON, unknown property, wrong type, bad query parameter.
  malformedRequest('MALFORMED_REQUEST', 400),

  /// No or invalid credentials.
  unauthenticated('UNAUTHENTICATED', 401),

  /// Authenticated but not allowed.
  forbidden('FORBIDDEN', 403),

  /// Unknown resource, or one the caller may not see.
  notFound('NOT_FOUND', 404),

  /// Method not supported.
  methodNotAllowed('METHOD_NOT_ALLOWED', 405),

  /// No acceptable representation for `Accept`.
  notAcceptable('NOT_ACCEPTABLE', 406),

  /// Concurrent modification without `If-Match`, or a uniqueness or
  /// integrity conflict.
  conflict('CONFLICT', 409),

  /// `If-Match` does not match the current version (stale `ETag`).
  preconditionFailed('PRECONDITION_FAILED', 412),

  /// Request body over 1 MB.
  payloadTooLarge('PAYLOAD_TOO_LARGE', 413),

  /// Body media type not supported.
  unsupportedMediaType('UNSUPPORTED_MEDIA_TYPE', 415),

  /// Well-formed request with invalid values (`errors` lists them).
  validationError('VALIDATION_ERROR', 422),

  /// A domain rule refused the action.
  businessRuleViolation('BUSINESS_RULE_VIOLATION', 422),

  /// `If-Match` missing where the resource requires it.
  preconditionRequired('PRECONDITION_REQUIRED', 428),

  /// Too many requests (`Retry-After` in seconds).
  rateLimited('RATE_LIMITED', 429),

  /// Anything unexpected on the server.
  internalError('INTERNAL_ERROR', 500),

  /// A vendor failed or answered unusably.
  upstreamError('UPSTREAM_ERROR', 502),

  /// A dependency is unavailable or overloaded (`Retry-After` in seconds).
  serviceUnavailable('SERVICE_UNAVAILABLE', 503),

  /// A vendor did not answer in time.
  upstreamTimeout('UPSTREAM_TIMEOUT', 504);

  const BackendErrorCode(this.wireName, this.impliedStatus);

  /// The value sent by the backend.
  final String wireName;

  /// The HTTP status the backend sends with this code (ADR 0012).
  /// Informative only: classification uses the transport status.
  final int impliedStatus;

  /// The code for [wireName], or null for a missing or unknown code (the
  /// raw string is still kept on the exception and failure).
  static BackendErrorCode? fromWire(String? wireName) {
    if (wireName == null) return null;
    for (final code in values) {
      if (code.wireName == wireName) return code;
    }
    return null;
  }
}
