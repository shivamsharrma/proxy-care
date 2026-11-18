package in.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;

import in.proxycare.shared.error.ErrorCode;
import in.proxycare.shared.error.FieldValidationError;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import tools.jackson.databind.JsonNode;

/**
 * Assertions for the API contract (ADR 0012): exactly these fields, nothing more.
 *
 * <pre>{@code
 * var result = mvc.post().uri("/api/v1/probes").contentType(JSON).content(body).exchange();
 * JsonNode problem = ApiAssertions.assertProblem(result.getResponse().getContentAsString(),
 *     ErrorCode.VALIDATION_ERROR);
 * }</pre>
 */
public final class ApiAssertions {

  /** Fields every problem has; {@code errors} is added only for field problems. */
  public static final Set<String> PROBLEM_FIELDS =
      Set.of("type", "title", "status", "detail", "instance", "code", "traceId", "timestamp");

  private ApiAssertions() {}

  /** A single-resource body; returns its {@code data}. */
  public static JsonNode assertData(String body) {
    JsonNode root = TestJson.tree(body);
    assertThat(fieldNames(root)).as("top-level fields").containsExactly("data");
    return root.path("data");
  }

  /** A collection body; returns the whole body for assertions on {@code data} and {@code page}. */
  public static JsonNode assertPage(String body) {
    JsonNode root = TestJson.tree(body);
    assertThat(fieldNames(root)).as("top-level fields").containsExactlyInAnyOrder("data", "page");
    assertThat(root.path("data").isArray()).as("data is an array").isTrue();
    assertThat(fieldNames(root.path("page")))
        .as("page fields")
        .containsExactlyInAnyOrder("nextCursor", "hasMore", "size");
    return root;
  }

  /**
   * A problem for {@code code}, with exactly the contract's fields; returns it. {@code errors} is
   * allowed only when present and non-empty.
   */
  public static JsonNode assertProblem(String body, ErrorCode code) {
    JsonNode problem = TestJson.tree(body);
    List<String> fields = fieldNames(problem);
    if (problem.has("errors")) {
      assertThat(problem.path("errors").isArray() && !problem.path("errors").isEmpty())
          .as("errors is a non-empty array when present")
          .isTrue();
      assertThat(fields).containsExactlyInAnyOrderElementsOf(withErrors());
    } else {
      assertThat(fields).as("problem fields").containsExactlyInAnyOrderElementsOf(PROBLEM_FIELDS);
    }
    assertThat(problem.path("type").asString()).isEqualTo(code.type());
    assertThat(problem.path("title").asString()).isEqualTo(code.title());
    assertThat(problem.path("status").asInt()).isEqualTo(code.status());
    assertThat(problem.path("code").asString()).isEqualTo(code.name());
    assertThat(problem.path("detail").asString()).isNotBlank();
    assertThat(problem.path("instance").asString()).startsWith("/");
    assertThat(problem.path("traceId").asString()).matches("[0-9a-f]{32}");
    assertThat(Instant.parse(problem.path("timestamp").asString())).isNotNull();
    return problem;
  }

  /** The problem's {@code errors}; empty when absent. */
  public static List<FieldValidationError> errors(JsonNode problem) {
    List<FieldValidationError> errors = new ArrayList<>();
    problem
        .path("errors")
        .forEach(error ->
            errors.add(
                new FieldValidationError(
                    error.path("field").asString(),
                    error.path("code").asString(),
                    error.path("message").asString())));
    return errors;
  }

  private static List<String> fieldNames(JsonNode node) {
    List<String> names = new ArrayList<>();
    node.propertyNames().forEach(names::add);
    return names;
  }

  private static List<String> withErrors() {
    List<String> fields = new ArrayList<>(PROBLEM_FIELDS);
    fields.add("errors");
    return fields;
  }
}
