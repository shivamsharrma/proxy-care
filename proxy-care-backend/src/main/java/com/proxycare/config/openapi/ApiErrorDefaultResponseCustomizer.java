package com.proxycare.config.openapi;

import com.proxycare.common.api.ApiError;
import io.swagger.v3.core.converter.ModelConverters;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.media.Schema;
import io.swagger.v3.oas.models.responses.ApiResponse;
import org.springdoc.core.customizers.OpenApiCustomizer;

/**
 * Documents ApiError as every operation's {@code default} response. Runs after springdoc has scanned the
 * controllers (which replaces any schemas registered up front), and builds the schema from the ApiError
 * record itself, so the docs can't drift from the JSON the handlers write.
 */
class ApiErrorDefaultResponseCustomizer implements OpenApiCustomizer {

    static final String SCHEMA_REF = "#/components/schemas/" + ApiError.class.getSimpleName();

    @Override
    public void customise(OpenAPI api) {
        addApiErrorSchemas(api);
        var error = errorResponse();
        api.getPaths().values().forEach(path -> path.readOperations().forEach(op -> addDefault(op, error)));
    }

    private static void addApiErrorSchemas(OpenAPI api) {
        ModelConverters.getInstance(true)
                .readAll(ApiError.class)
                .forEach((name, schema) -> api.getComponents().addSchemas(name, schema));
    }

    private static ApiResponse errorResponse() {
        var json = new MediaType().schema(new Schema<>().$ref(SCHEMA_REF));
        return new ApiResponse()
                .description("Error")
                .content(new Content().addMediaType("application/json", json));
    }

    private static void addDefault(Operation operation, ApiResponse error) {
        operation.getResponses().addApiResponse("default", error);
    }
}
