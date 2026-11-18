package in.proxycare.support;

import java.util.TimeZone;
import tools.jackson.databind.DeserializationFeature;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * JSON for tests that run without Spring. Configured like the application's mapper (application.yml
 * {@code spring.jackson.*}); ProxyCareApplicationTest checks they agree. In integration tests,
 * inject the application's {@code JsonMapper} instead.
 */
public final class TestJson {

  private static final JsonMapper MAPPER =
      JsonMapper.builder()
          .enable(
              DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES,
              DeserializationFeature.FAIL_ON_NULL_FOR_PRIMITIVES)
          .disable(DeserializationFeature.ACCEPT_FLOAT_AS_INT)
          .defaultTimeZone(TimeZone.getTimeZone("UTC"))
          .build();

  private TestJson() {}

  public static JsonMapper mapper() {
    return MAPPER;
  }

  public static String write(Object value) {
    return MAPPER.writeValueAsString(value);
  }

  public static <T> T read(String json, Class<T> type) {
    return MAPPER.readValue(json, type);
  }

  public static JsonNode tree(String json) {
    return MAPPER.readTree(json);
  }
}
