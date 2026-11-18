package in.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import in.proxycare.shared.error.ErrorCode;
import in.proxycare.shared.error.FieldValidationError;
import org.junit.jupiter.api.Test;

/** The assertions accept exactly the ADR 0012 shapes and reject anything extra or missing. */
class ApiAssertionsTest {

  private static final String VALIDATION_PROBLEM =
      """
      {
        "type": "urn:proxycare:problem:validation-error",
        "title": "Validation failed",
        "status": 422,
        "detail": "The request contains invalid values.",
        "instance": "/api/v1/patients",
        "code": "VALIDATION_ERROR",
        "traceId": "4bf92f3577b34da6a3ce929d0e0e4736",
        "timestamp": "2026-11-18T09:30:00Z",
        "errors": [{"field": "age", "code": "Max", "message": "must be less than or equal to 120"}]
      }
      """;

  @Test
  void acceptsTheDocumentedProblem() {
    var problem = ApiAssertions.assertProblem(VALIDATION_PROBLEM, ErrorCode.VALIDATION_ERROR);

    assertThat(ApiAssertions.errors(problem))
        .containsExactly(
            new FieldValidationError("age", "Max", "must be less than or equal to 120"));
  }

  @Test
  void rejectsAnotherCode() {
    assertThatThrownBy(() ->
            ApiAssertions.assertProblem(VALIDATION_PROBLEM, ErrorCode.BUSINESS_RULE_VIOLATION))
        .isInstanceOf(AssertionError.class);
  }

  @Test
  void rejectsExtraFields() {
    String leaky = VALIDATION_PROBLEM.replace("\"code\":", "\"exception\": \"x\", \"code\":");

    assertThatThrownBy(() -> ApiAssertions.assertProblem(leaky, ErrorCode.VALIDATION_ERROR))
        .isInstanceOf(AssertionError.class);
  }

  @Test
  void rejectsAMissingTraceId() {
    String withoutTrace =
        VALIDATION_PROBLEM.replace("\"traceId\": \"4bf92f3577b34da6a3ce929d0e0e4736\",", "");

    assertThatThrownBy(() -> ApiAssertions.assertProblem(withoutTrace, ErrorCode.VALIDATION_ERROR))
        .isInstanceOf(AssertionError.class);
  }

  @Test
  void acceptsDataAndPageBodies() {
    assertThat(ApiAssertions.assertData("{\"data\": {\"id\": \"x\"}}").path("id").asString())
        .isEqualTo("x");
    assertThat(
            ApiAssertions.assertPage(
                    "{\"data\": [], \"page\": {\"nextCursor\": null, \"hasMore\": false, \"size\": 20}}")
                .path("page")
                .path("size")
                .asInt())
        .isEqualTo(20);
  }

  @Test
  void rejectsTheOldEnvelope() {
    assertThatThrownBy(
            () -> ApiAssertions.assertData("{\"success\": true, \"data\": {}, \"meta\": {}}"))
        .isInstanceOf(AssertionError.class);
  }
}
