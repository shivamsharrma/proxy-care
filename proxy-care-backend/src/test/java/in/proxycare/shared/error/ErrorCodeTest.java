package in.proxycare.shared.error;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Arrays;
import org.junit.jupiter.api.Test;

class ErrorCodeTest {

  @Test
  void hasAStableUrnTypePerCode() {
    assertThat(ErrorCode.VALIDATION_ERROR.type())
        .isEqualTo("urn:proxycare:problem:validation-error");
    assertThat(Arrays.stream(ErrorCode.values()).map(ErrorCode::type)).doesNotHaveDuplicates();
  }

  @Test
  void everyCodeIsAnErrorStatusWithTitleAndDetail() {
    assertThat(ErrorCode.values())
        .allSatisfy(code -> {
          assertThat(code.status()).isBetween(400, 599);
          assertThat(code.title()).isNotBlank();
          assertThat(code.defaultDetail()).isNotBlank();
        });
  }

  @Test
  void keepsTheWireNamesClientsUse() {
    // ADR 0012 lists these; renaming one breaks clients.
    assertThat(Arrays.stream(ErrorCode.values()).map(Enum::name))
        .containsExactly(
            "MALFORMED_REQUEST",
            "UNAUTHENTICATED",
            "FORBIDDEN",
            "NOT_FOUND",
            "METHOD_NOT_ALLOWED",
            "NOT_ACCEPTABLE",
            "CONFLICT",
            "PRECONDITION_FAILED",
            "PAYLOAD_TOO_LARGE",
            "UNSUPPORTED_MEDIA_TYPE",
            "VALIDATION_ERROR",
            "BUSINESS_RULE_VIOLATION",
            "PRECONDITION_REQUIRED",
            "RATE_LIMITED",
            "INTERNAL_ERROR",
            "UPSTREAM_ERROR",
            "SERVICE_UNAVAILABLE",
            "UPSTREAM_TIMEOUT");
  }
}
