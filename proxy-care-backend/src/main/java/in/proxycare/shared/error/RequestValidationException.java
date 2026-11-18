package in.proxycare.shared.error;

import java.util.List;

/**
 * Values that Bean Validation cannot check declaratively were invalid, for example a malformed
 * pagination cursor (422 with field errors).
 */
public class RequestValidationException extends ProxyCareException {

  private static final long serialVersionUID = 1L;

  public RequestValidationException(List<FieldValidationError> errors) {
    super(
        ErrorCode.VALIDATION_ERROR, ErrorCode.VALIDATION_ERROR.defaultDetail(), errors, null, null);
    if (errors.isEmpty()) {
      throw new IllegalArgumentException("at least one field error is required");
    }
  }

  public static RequestValidationException of(String field, String code, String message) {
    return new RequestValidationException(List.of(new FieldValidationError(field, code, message)));
  }
}
