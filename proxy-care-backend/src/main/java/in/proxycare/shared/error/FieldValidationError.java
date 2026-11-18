package in.proxycare.shared.error;

import java.util.Objects;

/**
 * One invalid value in a request (an entry of the problem's {@code errors}). Never carries the
 * rejected value, which may be personal data.
 *
 * @param field property path such as {@code patient.age} or {@code purposes[0]}; empty for an
 *     object-level error
 * @param code what was violated, such as {@code NotBlank}, {@code Max} or {@code UnknownProperty}
 * @param message English explanation for developers
 */
public record FieldValidationError(String field, String code, String message) {

  public FieldValidationError {
    Objects.requireNonNull(field, "field");
    Objects.requireNonNull(code, "code");
    Objects.requireNonNull(message, "message");
  }
}
