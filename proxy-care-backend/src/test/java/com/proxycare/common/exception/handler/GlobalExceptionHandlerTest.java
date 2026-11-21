package com.proxycare.common.exception.handler;

import static com.proxycare.support.ApiErrorAssert.assertApiError;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;

import com.proxycare.support.IntegrationTest;
import com.proxycare.support.MutableClock;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

class GlobalExceptionHandlerTest extends IntegrationTest {

    private final UUID userId = UUID.randomUUID();

    @Test
    void validationErrorListsTheField() throws Exception {
        var result = mockMvc.perform(post("/api/v1/_probe/validated")
                .header("Authorization", bearer(userId))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"phone\":\"+919876543210\",\"otp\":\"123456\",\"age\":500}"));

        assertApiError(result, 400, "VALIDATION_FAILED")
                .andExpect(jsonPath("$.fieldErrors.age").value("must be less than or equal to 120"))
                .andExpect(jsonPath("$.fieldErrors.phone").doesNotExist());
    }

    @Test
    void malformedJson() throws Exception {
        var result = mockMvc.perform(post("/api/v1/_probe/validated")
                .header("Authorization", bearer(userId))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{not json"));

        assertApiError(result, 400, "MALFORMED_REQUEST").andExpect(jsonPath("$.fieldErrors").doesNotExist());
    }

    @Test
    void appExceptionNotFound() throws Exception {
        var result = mockMvc.perform(get("/api/v1/_probe/not-found").header("Authorization", bearer(userId)));

        assertApiError(result, 404, "RESOURCE_NOT_FOUND").andExpect(jsonPath("$.message").value("Thing not found."));
    }

    @Test
    void unknownApiPath() throws Exception {
        var result = mockMvc.perform(get("/api/v1/does-not-exist").header("Authorization", bearer(userId)));

        assertApiError(result, 404, "RESOURCE_NOT_FOUND");
    }

    @Test
    void wrongMethod() throws Exception {
        var result = mockMvc.perform(delete("/api/v1/_probe/items").header("Authorization", bearer(userId)));

        assertApiError(result, 400, "INVALID_PARAMETER");
    }

    @Test
    void unsupportedMediaType() throws Exception {
        var result = mockMvc.perform(post("/api/v1/_probe/validated")
                .header("Authorization", bearer(userId))
                .contentType(MediaType.TEXT_PLAIN)
                .content("hello"));

        assertApiError(result, 415, "UNSUPPORTED_MEDIA_TYPE");
    }

    @Test
    void timestampComesFromTheClock() throws Exception {
        var result = mockMvc.perform(get("/api/v1/_probe/not-found").header("Authorization", bearer(userId)));

        assertApiError(result, 404, "RESOURCE_NOT_FOUND")
                .andExpect(jsonPath("$.meta.timestamp").value(MutableClock.DEFAULT_INSTANT.toString()));
    }

    @Test
    void bodyOverOneMegabyte() throws Exception {
        var result = mockMvc.perform(post("/api/v1/_probe/validated")
                .header("Authorization", bearer(userId))
                .contentType(MediaType.APPLICATION_JSON)
                .content(new byte[1024 * 1024 + 1]));

        assertApiError(result, 413, "PAYLOAD_TOO_LARGE");
    }

    @Test
    void unexpectedExceptionHidesInternals() throws Exception {
        var result = mockMvc.perform(get("/api/v1/_probe/boom").header("Authorization", bearer(userId)));

        var body = assertApiError(result, 500, "INTERNAL_ERROR")
                .andReturn()
                .getResponse()
                .getContentAsString();
        assertThat(body)
                .doesNotContain("secret internal detail")
                .doesNotContain("IllegalStateException")
                .doesNotContain("java.lang")
                .doesNotContain("com.proxycare")
                .doesNotContain("\tat ");
    }
}
