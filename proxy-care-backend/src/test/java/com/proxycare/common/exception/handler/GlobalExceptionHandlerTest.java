package com.proxycare.common.error;

import static com.proxycare.support.ProblemJsonAssert.assertProblem;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

class ErrorFormatTest extends IntegrationTest {

    private final UUID userId = UUID.randomUUID();

    @Test
    void validationErrorListsTheField() throws Exception {
        var result = mvc.perform(post("/api/v1/_probe/validated")
                .header("Authorization", bearer(userId))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"phone\":\"+919876543210\",\"otp\":\"123456\",\"age\":500}"));

        assertProblem(result, 400, "VALIDATION_FAILED")
                .andExpect(jsonPath("$.errors[0].field").value("age"))
                .andExpect(jsonPath("$.errors[0].message").value("must be less than or equal to 120"))
                .andExpect(jsonPath("$.instance").value("/api/v1/_probe/validated"));
    }

    @Test
    void malformedJson() throws Exception {
        var result = mvc.perform(post("/api/v1/_probe/validated")
                .header("Authorization", bearer(userId))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{not json"));

        assertProblem(result, 400, "MALFORMED_REQUEST").andExpect(jsonPath("$.errors").doesNotExist());
    }

    @Test
    void appExceptionNotFound() throws Exception {
        var result = mvc.perform(get("/api/v1/_probe/not-found").header("Authorization", bearer(userId)));

        assertProblem(result, 404, "NOT_FOUND").andExpect(jsonPath("$.detail").value("Thing not found."));
    }

    @Test
    void unknownApiPath() throws Exception {
        var result = mvc.perform(get("/api/v1/does-not-exist").header("Authorization", bearer(userId)));

        assertProblem(result, 404, "NOT_FOUND");
    }

    @Test
    void wrongMethod() throws Exception {
        var result = mvc.perform(delete("/api/v1/_probe/items").header("Authorization", bearer(userId)));

        assertProblem(result, 405, "METHOD_NOT_ALLOWED");
    }

    @Test
    void bodyOverOneMegabyte() throws Exception {
        var result = mvc.perform(post("/api/v1/_probe/validated")
                .header("Authorization", bearer(userId))
                .contentType(MediaType.APPLICATION_JSON)
                .content(new byte[1024 * 1024 + 1]));

        assertProblem(result, 413, "PAYLOAD_TOO_LARGE");
    }

    @Test
    void unexpectedExceptionHidesInternals() throws Exception {
        var result = mvc.perform(get("/api/v1/_probe/boom").header("Authorization", bearer(userId)));

        var body = assertProblem(result, 500, "INTERNAL_ERROR")
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
