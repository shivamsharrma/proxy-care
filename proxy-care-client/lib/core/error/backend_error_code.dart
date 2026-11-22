/// The backend's error codes: the `code` member of an `ApiError` body,
/// named exactly as `com.proxycare.common.exception.ErrorCode`. Stable,
/// machine-readable identifiers: error handling and localized messages may
/// branch on them, never on the error's `message`.
///
/// HTTP status codes stay authoritative for transport-level classification;
/// a code only refines what the status leaves open (for example a 422 that
/// is a business-rule violation rather than invalid input). The backend
/// may add codes: an unknown code is kept as a raw string and the error is
/// classified by its HTTP status.
///
/// Pure Dart: failures carry it into the domain and presentation layers.
enum BackendErrorCode {
  /// Bean Validation rejected the body (`fieldErrors` lists the fields).
  validationFailed('VALIDATION_FAILED', 400),

  /// An unreadable body, a parameter that is missing or of the wrong type,
  /// or another Spring client error (sent as 400).
  malformedRequest('MALFORMED_REQUEST', 400),

  /// HTTP method not supported.
  invalidParameter('INVALID_PARAMETER', 400),

  /// No or invalid credentials.
  unauthenticated('UNAUTHENTICATED', 401),

  /// Authenticated but not allowed.
  accessDenied('ACCESS_DENIED', 403),

  /// Unknown resource, or one the caller may not see.
  resourceNotFound('RESOURCE_NOT_FOUND', 404),

  /// The caller has no profile yet.
  profileNotFound('PROFILE_NOT_FOUND', 404),

  /// A uniqueness or integrity conflict.
  resourceAlreadyExists('RESOURCE_ALREADY_EXISTS', 409),

  /// The resource changed since it was read (optimistic locking).
  concurrentModification('CONCURRENT_MODIFICATION', 409),

  /// Request body over the size limit.
  payloadTooLarge('PAYLOAD_TOO_LARGE', 413),

  /// Body media type not supported.
  unsupportedMediaType('UNSUPPORTED_MEDIA_TYPE', 415),

  /// A domain rule refused the action.
  businessRuleViolation('BUSINESS_RULE_VIOLATION', 422),

  /// Anything unexpected on the server.
  internalError('INTERNAL_ERROR', 500),

  /// A vendor failed or answered unusably.
  externalServiceError('EXTERNAL_SERVICE_ERROR', 502),

  /// A vendor is unavailable.
  externalServiceUnavailable('EXTERNAL_SERVICE_UNAVAILABLE', 503);

  const BackendErrorCode(this.wireName, this.impliedStatus);

  /// The value sent by the backend.
  final String wireName;

  /// The HTTP status the backend sends with this code. Informative only:
  /// classification uses the transport status.
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
