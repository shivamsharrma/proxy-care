package com.proxycare.common.security;

import static com.proxycare.support.ProblemJsonAssert.assertProblem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class PublicEndpointsTest extends IntegrationTest {

    @Test
    void healthWithoutToken() throws Exception {
        mvc.perform(get("/actuator/health")).andExpect(status().isOk());
    }

    @Test
    void apiDocsWithoutTokenInTestProfile() throws Exception {
        mvc.perform(get("/v3/api-docs")).andExpect(status().isOk());
    }

    @Test
    void unknownApiPathWithTokenIsNotFound() throws Exception {
        assertProblem(
                mvc.perform(get("/api/v1/nothing-here").header("Authorization", bearer(UUID.randomUUID()))),
                404,
                "NOT_FOUND");
    }

    @Test
    void unknownPathOutsideApiIsDenied() throws Exception {
        assertProblem(mvc.perform(get("/admin/secret")), 401, "UNAUTHENTICATED");
    }
}
