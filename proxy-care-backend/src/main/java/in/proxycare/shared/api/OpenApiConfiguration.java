package in.proxycare.shared.api;

import in.proxycare.shared.error.ErrorCode;
import io.swagger.v3.core.converter.ModelConverters;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.PathItem;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.responses.ApiResponse;
import io.swagger.v3.oas.models.responses.ApiResponses;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springdoc.core.customizers.OpenApiCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * The OpenAPI document (ADR 0012): bearer authentication, the shared problem, field-error and
 * pagination schemas, the error-code table, and the standard error responses on every operation.
 */
@Configuration(proxyBeanMethods = false)
class OpenApiConfiguration {

  static final String BEARER_AUTH = "bearerAuth";
  static final String PROBLEM_SCHEMA = "Problem";
  static final String PROBLEM_JSON = "application/problem+json";

  /** Error responses every operation can return, unless it declares its own for that status. */
  static final List<ErrorCode> STANDARD_ERRORS =
      List.of(
          ErrorCode.MALFORMED_REQUEST,
          ErrorCode.UNAUTHENTICATED,
          ErrorCode.FORBIDDEN,
          ErrorCode.NOT_FOUND,
          ErrorCode.VALIDATION_ERROR,
          ErrorCode.RATE_LIMITED,
          ErrorCode.INTERNAL_ERROR,
          ErrorCode.SERVICE_UNAVAILABLE);

  @Bean
  OpenAPI proxyCareOpenApi() {
    Components components =
        new Components()
            .addSecuritySchemes(
                BEARER_AUTH,
                new SecurityScheme()
                    .type(SecurityScheme.Type.HTTP)
                    .scheme("bearer")
                    .bearerFormat("JWT")
                    .description("Supabase Auth access token."));
    ModelConverters converters = ModelConverters.getInstance(true);
    converters.readAll(ProblemDocument.class).forEach(components::addSchemas);
    converters.readAll(PageMetadata.class).forEach(components::addSchemas);
    for (ErrorCode code : STANDARD_ERRORS) {
      components.addResponses(responseName(code), standardResponse(code));
    }
    return new OpenAPI()
        .info(
            new Info()
                .title("Proxy Care API")
                .version("v1")
                .description(
                    "Errors use RFC 9457 problem details (application/problem+json). Clients"
                        + " branch on `code`, never on `title` or `detail`.\n\n"
                        + errorCodeTable()))
        .components(components)
        .addSecurityItem(new SecurityRequirement().addList(BEARER_AUTH));
  }

  @Bean
  OpenApiCustomizer standardErrorResponses() {
    return OpenApiConfiguration::addStandardErrorResponses;
  }

  static void addStandardErrorResponses(OpenAPI openApi) {
    if (openApi.getPaths() == null) {
      return;
    }
    for (PathItem path : openApi.getPaths().values()) {
      for (Operation operation : path.readOperations()) {
        ApiResponses responses = operation.getResponses();
        if (responses == null) {
          responses = new ApiResponses();
          operation.setResponses(responses);
        }
        for (ErrorCode code : STANDARD_ERRORS) {
          String status = Integer.toString(code.status());
          if (!responses.containsKey(status)) {
            responses.addApiResponse(
                status, new ApiResponse().$ref("#/components/responses/" + responseName(code)));
          }
        }
      }
    }
  }

  static String errorCodeTable() {
    StringBuilder table = new StringBuilder("| code | status | meaning |\n|---|---|---|\n");
    for (ErrorCode code : ErrorCode.values()) {
      table
          .append("| `")
          .append(code.name())
          .append("` | ")
          .append(code.status())
          .append(" | ")
          .append(code.defaultDetail())
          .append(" |\n");
    }
    return table.toString();
  }

  private static String responseName(ErrorCode code) {
    StringBuilder name = new StringBuilder();
    for (String word : code.name().split("_")) {
      name.append(word.charAt(0)).append(word.substring(1).toLowerCase(java.util.Locale.ROOT));
    }
    return name.toString();
  }

  private static ApiResponse standardResponse(ErrorCode code) {
    Map<String, Object> example = new LinkedHashMap<>();
    example.put("type", code.type());
    example.put("title", code.title());
    example.put("status", code.status());
    example.put("detail", code.defaultDetail());
    example.put("instance", ApiPaths.V1 + "/resources/0198f0c2-6a7b-7cc3-9f5e-2b3a4c5d6e7f");
    example.put("code", code.name());
    example.put("traceId", "4bf92f3577b34da6a3ce929d0e0e4736");
    example.put("timestamp", "2026-11-18T09:30:00Z");
    if (code == ErrorCode.VALIDATION_ERROR) {
      example.put(
          "errors",
          List.of(
              Map.of(
                  "field", "age", "code", "Max", "message", "must be less than or equal to 120")));
    }
    io.swagger.v3.oas.models.media.Schema<?> problem =
        new io.swagger.v3.oas.models.media.Schema<>()
            .$ref("#/components/schemas/" + PROBLEM_SCHEMA);
    return new ApiResponse()
        .description(code.title())
        .content(
            new Content()
                .addMediaType(PROBLEM_JSON, new MediaType().schema(problem).example(example)));
  }

  /** Documentation of the problem body; the actual body is Spring's ProblemDetail. */
  @Schema(name = PROBLEM_SCHEMA, description = "RFC 9457 problem details (ADR 0012).")
  record ProblemDocument(
      @Schema(
              description = "Problem type URI, stable per code.",
              example = "urn:proxycare:problem:validation-error")
          String type,
      @Schema(description = "Fixed summary of the code.", example = "Validation failed")
          String title,
      @Schema(description = "HTTP status.", example = "422") int status,
      @Schema(
              description = "Short English explanation for developers; never shown to users.",
              example = "The request contains invalid values.")
          String detail,
      @Schema(description = "Request path, without the query string.", example = "/api/v1/patients")
          String instance,
      @Schema(description = "Stable error code. Clients branch on this.") ErrorCode code,
      @Schema(
              description = "Identifies the request in server logs and traces.",
              example = "4bf92f3577b34da6a3ce929d0e0e4736")
          String traceId,
      @Schema(description = "When the error occurred (UTC).", example = "2026-11-18T09:30:00Z")
          Instant timestamp,
      @Schema(description = "Field-level problems; present only when applicable.", nullable = true)
          List<FieldErrorDocument> errors) {}

  /** Documentation of one entry of a problem's errors. */
  @Schema(name = "FieldValidationError", description = "One invalid value in the request.")
  record FieldErrorDocument(
      @Schema(
              description = "Property path; empty for an object-level error.",
              example = "patient.age")
          String field,
      @Schema(description = "What was violated.", example = "Max") String code,
      @Schema(description = "English explanation.", example = "must be less than or equal to 120")
          String message) {}
}
