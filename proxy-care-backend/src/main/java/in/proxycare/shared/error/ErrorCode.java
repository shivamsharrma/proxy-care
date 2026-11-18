package in.proxycare.shared.error;

import java.util.Locale;

/**
 * Every error the API can return (ADR 0012). The {@link #name()} is the wire value of the problem's
 * {@code code}; clients branch on it, never on the title or detail. Pure Java so domain code can
 * use it.
 */
public enum ErrorCode {
  MALFORMED_REQUEST(400, "Malformed request", "The request could not be read."),
  UNAUTHENTICATED(401, "Authentication required", "Valid credentials are required."),
  FORBIDDEN(403, "Forbidden", "You are not allowed to perform this action."),
  NOT_FOUND(404, "Not found", "The requested resource was not found."),
  METHOD_NOT_ALLOWED(405, "Method not allowed", "This method is not supported for the resource."),
  NOT_ACCEPTABLE(406, "Not acceptable", "No acceptable representation is available."),
  CONFLICT(409, "Conflict", "The request conflicts with the current state of the resource."),
  PRECONDITION_FAILED(
      412, "Precondition failed", "The resource has changed since it was last read."),
  PAYLOAD_TOO_LARGE(413, "Payload too large", "The request body is too large."),
  UNSUPPORTED_MEDIA_TYPE(
      415, "Unsupported media type", "The request body's content type is not supported."),
  VALIDATION_ERROR(422, "Validation failed", "The request contains invalid values."),
  BUSINESS_RULE_VIOLATION(422, "Business rule violated", "The action is not allowed."),
  PRECONDITION_REQUIRED(428, "Precondition required", "This request requires an If-Match header."),
  RATE_LIMITED(429, "Too many requests", "Too many requests. Try again later."),
  INTERNAL_ERROR(500, "Internal error", "An unexpected error occurred."),
  UPSTREAM_ERROR(502, "Upstream error", "A partner service failed."),
  SERVICE_UNAVAILABLE(
      503, "Service unavailable", "The service is temporarily unavailable. Try again later."),
  UPSTREAM_TIMEOUT(504, "Upstream timeout", "A partner service did not respond in time.");

  private static final String TYPE_PREFIX = "urn:proxycare:problem:";

  private final int status;
  private final String title;
  private final String defaultDetail;

  ErrorCode(int status, String title, String defaultDetail) {
    this.status = status;
    this.title = title;
    this.defaultDetail = defaultDetail;
  }

  /** HTTP status. */
  public int status() {
    return status;
  }

  /** Fixed, human-readable summary of the code. */
  public String title() {
    return title;
  }

  /** Detail used when nothing more specific is safe to say. */
  public String defaultDetail() {
    return defaultDetail;
  }

  /** The problem {@code type} URI: {@code urn:proxycare:problem:validation-error}. */
  public String type() {
    return TYPE_PREFIX + name().toLowerCase(Locale.ROOT).replace('_', '-');
  }
}
