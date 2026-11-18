package in.proxycare.shared.error;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatIllegalArgumentException;

import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;

class ProxyCareExceptionTest {

  @Test
  void subclassesCarryTheirCodes() {
    assertThat(new NotFoundException().code()).isEqualTo(ErrorCode.NOT_FOUND);
    assertThat(new ConflictException().code()).isEqualTo(ErrorCode.CONFLICT);
    assertThat(new BusinessRuleViolationException("no").code())
        .isEqualTo(ErrorCode.BUSINESS_RULE_VIOLATION);
    assertThat(new ForbiddenException().code()).isEqualTo(ErrorCode.FORBIDDEN);
    assertThat(new UpstreamException("down", null).code()).isEqualTo(ErrorCode.UPSTREAM_ERROR);
    assertThat(UpstreamException.timeout("slow", null).code())
        .isEqualTo(ErrorCode.UPSTREAM_TIMEOUT);
    assertThat(new PreconditionFailedException().code()).isEqualTo(ErrorCode.PRECONDITION_FAILED);
    assertThat(new PreconditionRequiredException().code())
        .isEqualTo(ErrorCode.PRECONDITION_REQUIRED);
  }

  @Test
  void usesTheDefaultDetailUnlessGivenOne() {
    assertThat(new NotFoundException().getMessage()).isEqualTo(ErrorCode.NOT_FOUND.defaultDetail());
    assertThat(new NotFoundException("No such visit.").getMessage()).isEqualTo("No such visit.");
  }

  @Test
  void keepsTheVendorCauseForLogsOnly() {
    RuntimeException vendor = new RuntimeException("vendor body");

    UpstreamException exception = new UpstreamException("The payment gateway failed.", vendor);

    assertThat(exception.getMessage()).isEqualTo("The payment gateway failed.");
    assertThat(exception.getCause()).isSameAs(vendor);
  }

  @Test
  void carriesRetryAfterForThrottling() {
    assertThat(ProxyCareException.rateLimited(Duration.ofSeconds(9)).retryAfter())
        .contains(Duration.ofSeconds(9));
    assertThat(ProxyCareException.serviceUnavailable(null, null).retryAfter()).isEmpty();
    assertThat(new ConflictException().retryAfter()).isEmpty();
  }

  @Test
  void validationNeedsAtLeastOneFieldError() {
    assertThat(RequestValidationException.of("size", "Range", "must be between 1 and 100").errors())
        .containsExactly(new FieldValidationError("size", "Range", "must be between 1 and 100"));
    assertThatIllegalArgumentException()
        .isThrownBy(() -> new RequestValidationException(List.of()));
  }
}
