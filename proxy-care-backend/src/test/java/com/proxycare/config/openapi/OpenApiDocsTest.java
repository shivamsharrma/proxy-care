package com.proxycare.config.openapi;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import com.proxycare.common.api.ApiError;
import com.proxycare.common.api.ResponseMeta;
import com.proxycare.support.IntegrationTest;
import java.lang.reflect.RecordComponent;
import java.util.Arrays;
import java.util.List;
import java.util.stream.StreamSupport;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;

class OpenApiDocsTest extends IntegrationTest {

    @Test
    void everyOperationRequiresTheBearerToken() throws Exception {
        var docs = apiDocs();
        assertThat(docs.at("/components/securitySchemes/bearer/scheme").asString()).isEqualTo("bearer");
        assertThat(docs.at("/components/securitySchemes/bearer/bearerFormat").asString()).isEqualTo("JWT");
        assertThat(docs.at("/security/0").has("bearer")).isTrue();
    }

    @Test
    void apiErrorSchemaMatchesTheApiErrorRecord() throws Exception {
        var docs = apiDocs();
        var apiError = schema(docs, ApiError.class.getSimpleName());
        assertThat(propertyNames(apiError)).containsExactlyInAnyOrderElementsOf(recordFields(ApiError.class));

        var meta = schema(docs, refName(apiError.at("/properties/meta/$ref")));
        assertThat(propertyNames(meta)).containsExactlyInAnyOrderElementsOf(recordFields(ResponseMeta.class));
        assertThat(meta.at("/properties/timestamp/format").asString()).isEqualTo("date-time");
    }

    @Test
    void everyOperationDocumentsApiErrorAsItsDefaultResponse() throws Exception {
        var paths = apiDocs().get("paths");
        assertThat(paths.isEmpty()).isFalse();
        paths.forEach(path -> path.forEach(operation -> assertThat(
                        operation.at("/responses/default/content/application~1json/schema/$ref").asString())
                .isEqualTo("#/components/schemas/ApiError")));
    }

    private JsonNode apiDocs() throws Exception {
        var body = mockMvc.perform(get("/v3/api-docs")).andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(body);
    }

    private static JsonNode schema(JsonNode docs, String name) {
        var schema = docs.at("/components/schemas/" + name);
        assertThat(schema.isMissingNode()).as("schema %s", name).isFalse();
        return schema;
    }

    private static String refName(JsonNode ref) {
        return ref.asString().substring("#/components/schemas/".length());
    }

    private static List<String> propertyNames(JsonNode schema) {
        return StreamSupport.stream(schema.get("properties").propertyNames().spliterator(), false).toList();
    }

    private static List<String> recordFields(Class<? extends Record> type) {
        return Arrays.stream(type.getRecordComponents()).map(RecordComponent::getName).toList();
    }
}
