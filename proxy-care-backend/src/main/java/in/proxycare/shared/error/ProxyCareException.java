package in.proxycare.shared.error;

import java.time.Duration;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

/**
 * An expected failure that maps to one {@link ErrorCode} (ADR 0012). The subclasses name the common
 * cases; use this class directly for the remaining codes.
 *
 * <p>The {@linkplain #getMessage() message} is sent to clients as the problem's {@code detail}, so
 * it must be a short English sentence with no personal data, ids of other users, SQL or vendor
 * text. Put diagnostic detail in the {@linkplain #getCause() cause}, which is only logged.
 */
public class ProxyCareException extends RuntimeException {

  private static final long serialVersionUID = 1L;

  private final ErrorCode code;
  private final transient List<FieldValidationError> errors;
  private final Duration retryAfter;

  public ProxyCareException(ErrorCode code) {
    this(code, code.defaultDetail(), List.of(), null, null);
  }

  public ProxyCareException(ErrorCode code, String detail) {
    this(code, detail, List.of(), null, null);
  }

  public ProxyCareException(ErrorCode code, String detail, Throwable cause) {
    this(code, detail, List.of(), null, cause);
  }

  /**
   * @param errors field-level problems, empty when not applicable
   * @param retryAfter when the client may retry (for 429 and 503), or null
   */
  protected ProxyCareException(
      ErrorCode code,
      String detail,
      List<FieldValidationError> errors,
      Duration retryAfter,
      Throwable cause) {
    super(Objects.requireNonNull(detail, "detail"), cause);
    this.code = Objects.requireNonNull(code, "code");
    this.errors = List.copyOf(errors);
    this.retryAfter = retryAfter;
  }

  /** Too many requests; the client may retry after {@code retryAfter}. */
  public static ProxyCareException rateLimited(Duration retryAfter) {
    return new ProxyCareException(
        ErrorCode.RATE_LIMITED,
        ErrorCode.RATE_LIMITED.defaultDetail(),
        List.of(),
        retryAfter,
        null);
  }

  /** A dependency is unavailable; the client may retry after {@code retryAfter} (nullable). */
  public static ProxyCareException serviceUnavailable(Duration retryAfter, Throwable cause) {
    return new ProxyCareException(
        ErrorCode.SERVICE_UNAVAILABLE,
        ErrorCode.SERVICE_UNAVAILABLE.defaultDetail(),
        List.of(),
        retryAfter,
        cause);
  }

  public ErrorCode code() {
    return code;
  }

  public List<FieldValidationError> errors() {
    return errors;
  }

  public Optional<Duration> retryAfter() {
    return Optional.ofNullable(retryAfter);
  }
}
