package in.proxycare.shared.api;

import static org.assertj.core.api.Assertions.assertThat;

import in.proxycare.shared.error.ErrorCode;
import in.proxycare.support.ApiAssertions;
import in.proxycare.support.IntegrationTest;
import in.proxycare.support.TestJson;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import tools.jackson.databind.JsonNode;

/**
 * Generates the OpenAPI document of the application's API and writes it to {@value #OUTPUT} on
 * every test run (ADR 0012), then checks its shared parts.
 */
@IntegrationTest
class OpenApiDocumentTest {

  static final String OUTPUT = "build/openapi/openapi.json";

  @Autowired private MockMvcTester mvc;

  private JsonNode document;

  @BeforeEach
  void generate() throws IOException {
    String json =
        mvc.get()
            .uri("/v3/api-docs")
            .exchange()
            .getResponse()
            .getContentAsString(StandardCharsets.UTF_8);
    Path output = Path.of(OUTPUT);
    Files.createDirectories(output.getParent());
    Files.writeString(output, json, StandardCharsets.UTF_8);
    document = TestJson.tree(json);
  }

  @Test
  void isOpenApi31WithBearerAuthentication() {
    assertThat(document.path("openapi").asString()).startsWith("3.1");
    JsonNode bearer = document.path("components").path("securitySchemes").path("bearerAuth");
    assertThat(bearer.path("type").asString()).isEqualTo("http");
    assertThat(bearer.path("scheme").asString()).isEqualTo("bearer");
    assertThat(bearer.path("bearerFormat").asString()).isEqualTo("JWT");
    assertThat(document.path("security").get(0).has("bearerAuth")).isTrue();
  }

  @Test
  void documentsTheProblemExactlyAsItIsSent() {
    JsonNode problem = document.path("components").path("schemas").path("Problem");

    List<String> properties = new ArrayList<>();
    problem.path("properties").propertyNames().forEach(properties::add);
    List<String> expected = new ArrayList<>(ApiAssertions.PROBLEM_FIELDS);
    expected.add("errors");
    assertThat(properties).containsExactlyInAnyOrderElementsOf(expected);
  }

  @Test
  void listsEveryErrorCode() {
    JsonNode code =
        document.path("components").path("schemas").path("Problem").path("properties").path("code");
    List<String> values = new ArrayList<>();
    code.path("enum").forEach(value -> values.add(value.asString()));

    assertThat(values)
        .containsExactlyInAnyOrderElementsOf(
            Arrays.stream(ErrorCode.values()).map(Enum::name).toList());
    assertThat(document.path("info").path("description").asString()).contains("`VALIDATION_ERROR`");
  }

  @Test
  void definesTheSharedSchemasAndErrorResponsesWithExamples() {
    JsonNode components = document.path("components");
    assertThat(components.path("schemas").has("FieldValidationError")).isTrue();
    List<String> page = new ArrayList<>();
    components
        .path("schemas")
        .path("PageMetadata")
        .path("properties")
        .propertyNames()
        .forEach(page::add);
    assertThat(page).containsExactlyInAnyOrder("nextCursor", "hasMore", "size");

    JsonNode validation =
        components
            .path("responses")
            .path("ValidationError")
            .path("content")
            .path("application/problem+json");
    assertThat(validation.path("schema").path("$ref").asString())
        .isEqualTo("#/components/schemas/Problem");
    assertThat(validation.path("example").path("code").asString()).isEqualTo("VALIDATION_ERROR");
  }

  @Test
  void containsOnlyTheApplicationApi() {
    // The test-only probe API is excluded; no production endpoint exists yet.
    document
        .path("paths")
        .propertyNames()
        .forEach(path -> assertThat(path).startsWith(ApiPaths.V1).doesNotContain("/probes"));
  }
}
