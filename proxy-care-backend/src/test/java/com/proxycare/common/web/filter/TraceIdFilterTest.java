package com.proxycare.common.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.api.Test;

class RequestIdTest extends IntegrationTest {

    private final UUID userId = UUID.randomUUID();

    @Test
    void validClientRequestIdIsEchoed() throws Exception {
        var sent = UUID.randomUUID().toString();

        var response = mvc.perform(get("/api/v1/_probe/items")
                        .header("Authorization", bearer(userId))
                        .header("X-Request-Id", sent))
                .andReturn()
                .getResponse();

        assertThat(response.getHeader("X-Request-Id")).isEqualTo(sent);
    }

    @Test
    void missingRequestIdIsGenerated() throws Exception {
        var response = mvc.perform(get("/api/v1/_probe/items").header("Authorization", bearer(userId)))
                .andReturn()
                .getResponse();

        assertThat(UUID.fromString(response.getHeader("X-Request-Id"))).isNotNull();
    }

    @ParameterizedTest
    @ValueSource(strings = {"abc\r\ninjected", "not-a-uuid"})
    void invalidRequestIdIsReplaced(String sent) throws Exception {
        assertReplaced(sent);
    }

    @Test
    void oversizedRequestIdIsReplaced() throws Exception {
        assertReplaced("a".repeat(500));
    }

    @Test
    void errorBodyRequestIdMatchesHeader() throws Exception {
        var response = mvc.perform(get("/api/v1/_probe/not-found").header("Authorization", bearer(userId)))
                .andReturn()
                .getResponse();

        var body = json.readTree(response.getContentAsString());
        assertThat(body.get("requestId").asString()).isEqualTo(response.getHeader("X-Request-Id"));
    }

    private void assertReplaced(String sent) throws Exception {
        var returned = mvc.perform(get("/api/v1/_probe/items")
                        .header("Authorization", bearer(userId))
                        .header("X-Request-Id", sent))
                .andReturn()
                .getResponse()
                .getHeader("X-Request-Id");

        assertThat(returned).isNotEqualTo(sent);
        assertThat(UUID.fromString(returned).toString()).isEqualTo(returned);
    }
}
