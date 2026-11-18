package in.proxycare.shared.api;

import static org.assertj.core.api.Assertions.assertThat;

import in.proxycare.shared.error.ErrorCode;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.PathItem;
import io.swagger.v3.oas.models.Paths;
import io.swagger.v3.oas.models.responses.ApiResponse;
import io.swagger.v3.oas.models.responses.ApiResponses;
import org.junit.jupiter.api.Test;

/** The customizer adds the shared error responses to every operation, without overriding any. */
class OpenApiConfigurationTest {

  @Test
  void addsTheStandardErrorResponsesToEveryOperation() {
    Operation operation =
        new Operation().responses(new ApiResponses().addApiResponse("200", new ApiResponse()));
    OpenAPI openApi =
        new OpenAPI()
            .paths(new Paths().addPathItem("/api/v1/things", new PathItem().get(operation)));

    OpenApiConfiguration.addStandardErrorResponses(openApi);

    assertThat(operation.getResponses())
        .containsKeys("200", "400", "401", "403", "404", "422", "429", "500", "503");
    assertThat(operation.getResponses().get("422").get$ref())
        .isEqualTo("#/components/responses/ValidationError");
  }

  @Test
  void keepsAnOperationsOwnErrorResponse() {
    ApiResponse own = new ApiResponse().description("Visit not found");
    Operation operation = new Operation().responses(new ApiResponses().addApiResponse("404", own));
    OpenAPI openApi =
        new OpenAPI()
            .paths(new Paths().addPathItem("/api/v1/things/{id}", new PathItem().get(operation)));

    OpenApiConfiguration.addStandardErrorResponses(openApi);

    assertThat(operation.getResponses().get("404")).isSameAs(own);
  }

  @Test
  void documentsEveryErrorCode() {
    String table = OpenApiConfiguration.errorCodeTable();

    for (ErrorCode code : ErrorCode.values()) {
      assertThat(table).contains("| `" + code.name() + "` | " + code.status() + " |");
    }
  }
}
