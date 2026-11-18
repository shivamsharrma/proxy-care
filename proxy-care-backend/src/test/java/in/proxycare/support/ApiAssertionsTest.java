package in.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.List;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;

/**
 * The envelope assertions accept exactly the shape the Flutter client parses. The error example is
 * the one documented in proxy-care-client/lib/core/error/error_mapper.dart.
 */
class ApiAssertionsTest {

  private static final String CLIENT_ERROR_EXAMPLE =
      """
      {
        "success": false,
        "data": null,
        "error": {
          "code": "VALIDATION_ERROR",
          "message": "Request validation failed",
          "fieldErrors": { "email": ["Invalid email address"] }
        },
        "meta": { "timestamp": "2026-01-15T09:00:00Z", "correlationId": "abc-123" }
      }
      """;

  private static final String SUCCESS_EXAMPLE =
      """
      {
        "success": true,
        "data": { "id": "PC-2481" },
        "error": null,
        "meta": { "timestamp": "2026-01-15T09:00:00Z", "correlationId": "abc-123" }
      }
      """;

  @Test
  void acceptsTheClientsDocumentedErrorShape() {
    JsonNode error = ApiAssertions.assertErrorEnvelope(CLIENT_ERROR_EXAMPLE, "VALIDATION_ERROR");

    assertThat(ApiAssertions.fieldErrors(error))
        .containsExactlyEntriesOf(java.util.Map.of("email", List.of("Invalid email address")));
  }

  @Test
  void failsOnAnotherErrorCode() {
    assertThatThrownBy(() -> ApiAssertions.assertErrorEnvelope(CLIENT_ERROR_EXAMPLE, "NOT_FOUND"))
        .isInstanceOf(AssertionError.class)
        .hasMessageContaining("error.code");
  }

  @Test
  void acceptsASuccessEnvelopeAndReturnsItsData() {
    JsonNode data = ApiAssertions.assertSuccessEnvelope(SUCCESS_EXAMPLE);

    assertThat(data.path("id").asString()).isEqualTo("PC-2481");
  }

  @Test
  void rejectsAnErrorReportedInsideASuccessEnvelope() {
    assertThatThrownBy(() -> ApiAssertions.assertSuccessEnvelope(CLIENT_ERROR_EXAMPLE))
        .isInstanceOf(AssertionError.class);
  }

  @Test
  void requiresTheCorrelationId() {
    String withoutCorrelationId =
        SUCCESS_EXAMPLE.replace("\"correlationId\": \"abc-123\"", "\"x\": 1");

    assertThatThrownBy(() -> ApiAssertions.assertSuccessEnvelope(withoutCorrelationId))
        .isInstanceOf(AssertionError.class)
        .hasMessageContaining("meta.correlationId");
  }
}
