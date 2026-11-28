package com.proxycare.common.security.config;

import static com.proxycare.support.ApiErrorAssert.assertApiError;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Which paths are public, which need a token, and that everything else is denied. */
class PathAccessTest extends IntegrationTest {

    @Test
    void healthIsPublic() throws Exception {
        mockMvc.perform(get("/actuator/health")).andExpect(status().isOk());
    }

    @Test
    void infoIsPublic() throws Exception {
        mockMvc.perform(get("/actuator/info")).andExpect(status().isOk());
    }

    @Test
    void apiDocsArePublic() throws Exception {
        mockMvc.perform(get("/v3/api-docs")).andExpect(status().isOk());
    }

    @Test
    void apiNeedsAToken() throws Exception {
        assertApiError(mockMvc.perform(get("/api/v1/_probe/whoami")), 401, "UNAUTHENTICATED");
    }

    @Test
    void unknownApiPathWithTokenIsNotFound() throws Exception {
        assertApiError(
                mockMvc.perform(get("/api/v1/nothing-here").header("Authorization", bearer(UUID.randomUUID()))),
                404,
                "RESOURCE_NOT_FOUND");
    }

    @Test
    void pathOutsideTheApiIsDeniedWithoutAToken() throws Exception {
        assertApiError(mockMvc.perform(get("/admin/secret")), 401, "UNAUTHENTICATED");
    }

    @Test
    void pathOutsideTheApiIsDeniedEvenWithAToken() throws Exception {
        assertApiError(
                mockMvc.perform(get("/admin/secret").header("Authorization", bearer(UUID.randomUUID()))),
                403,
                "ACCESS_DENIED");
    }

    /** No webhook exists, so the path is not opened in advance. */
    @Test
    void webhookPathsAreNotPublic() throws Exception {
        assertApiError(mockMvc.perform(get("/webhooks/razorpay")), 401, "UNAUTHENTICATED");
    }

    /** Reaches the controller without a token; the signature, not a token, is what it checks. */
    @Test
    void razorpayXWebhookIsPublicButNeedsAValidSignature() throws Exception {
        assertApiError(
                mockMvc.perform(post("/api/v1/webhooks/razorpayx")
                        .header("X-Razorpay-Event-Id", "evt_test")
                        .header("X-Razorpay-Signature", "not-a-valid-signature")
                        .contentType("application/json")
                        .content("{}")),
                400,
                "WEBHOOK_SIGNATURE_INVALID");
    }

    @Test
    void sensitiveActuatorEndpointsAreDenied() throws Exception {
        assertApiError(mockMvc.perform(get("/actuator/env")), 401, "UNAUTHENTICATED");
    }

    @Test
    void noSessionCookieIsCreated() throws Exception {
        mockMvc.perform(get("/api/v1/_probe/whoami").header("Authorization", bearer(UUID.randomUUID())))
                .andExpect(status().isOk())
                .andExpect(header().doesNotExist("Set-Cookie"));
    }

    @Test
    void securityHeadersAreSet() throws Exception {
        mockMvc.perform(get("/api/v1/_probe/whoami").header("Authorization", bearer(UUID.randomUUID())))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andExpect(header().string("X-Frame-Options", "DENY"));
    }
}
