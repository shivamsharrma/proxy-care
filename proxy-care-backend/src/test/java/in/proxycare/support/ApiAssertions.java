package in.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import tools.jackson.databind.JsonNode;

/**
 * Assertions for the response envelope every API endpoint returns (ADR 0005), as the Flutter client
 * parses it ({@code proxy-care-client/lib/core/error/error_mapper.dart}).
 *
 * <pre>{@code
 * assertThat(mvc.post().uri("/v1/bookings").content(body)).hasStatus(422);
 * ApiAssertions.assertErrorEnvelope(result.getResponse().getContentAsString(), "VALIDATION_ERROR");
 * }</pre>
 */
public final class ApiAssertions {

  private ApiAssertions() {}

  /** A success envelope; returns its {@code data} for further assertions. */
  public static JsonNode assertSuccessEnvelope(String body) {
    JsonNode envelope = TestJson.tree(body);
    assertThat(envelope.path("success").isBoolean() && envelope.path("success").asBoolean())
        .as("success is true")
        .isTrue();
    assertThat(envelope.has("data")).as("data is present").isTrue();
    assertThat(envelope.path("error").isNull()).as("error is null").isTrue();
    assertMeta(envelope);
    return envelope.path("data");
  }

  /** An error envelope with {@code expectedCode}; returns its {@code error} object. */
  public static JsonNode assertErrorEnvelope(String body, String expectedCode) {
    JsonNode envelope = TestJson.tree(body);
    assertThat(envelope.path("success").isBoolean() && !envelope.path("success").asBoolean())
        .as("success is false")
        .isTrue();
    assertThat(envelope.path("data").isNull()).as("data is null").isTrue();
    JsonNode error = envelope.path("error");
    assertThat(error.path("code").asString()).as("error.code").isEqualTo(expectedCode);
    assertThat(error.path("message").asString()).as("error.message").isNotBlank();
    assertMeta(envelope);
    return error;
  }

  /** {@code error.fieldErrors} as a map; empty when absent. */
  public static Map<String, List<String>> fieldErrors(JsonNode error) {
    Map<String, List<String>> result = new LinkedHashMap<>();
    error
        .path("fieldErrors")
        .properties()
        .forEach(field -> {
          List<String> messages = new ArrayList<>();
          field.getValue().forEach(message -> messages.add(message.asString()));
          result.put(field.getKey(), messages);
        });
    return result;
  }

  private static void assertMeta(JsonNode envelope) {
    JsonNode meta = envelope.path("meta");
    assertThat(meta.path("timestamp").asString()).as("meta.timestamp").isNotBlank();
    assertThat(meta.path("correlationId").asString()).as("meta.correlationId").isNotBlank();
  }
}
