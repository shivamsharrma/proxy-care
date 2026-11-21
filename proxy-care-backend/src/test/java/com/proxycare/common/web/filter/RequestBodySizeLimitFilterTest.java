package com.proxycare.common.web.filter;

import static com.proxycare.support.ApiErrorAssert.assertApiError;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.Arrays;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

class RequestBodySizeLimitFilterTest extends IntegrationTest {

    private final UUID userId = UUID.randomUUID();

    @Test
    void bodyOverTheLimitIsRejected() throws Exception {
        assertApiError(send(RequestBodySizeLimitFilter.MAX_BODY_BYTES + 1), 413, "PAYLOAD_TOO_LARGE")
                .andExpect(header().string("Cache-Control", "no-store"));
    }

    /** At exactly the limit the body reaches the controller, which rejects the padding as invalid JSON. */
    @Test
    void bodyAtTheLimitIsAllowedThrough() throws Exception {
        send(RequestBodySizeLimitFilter.MAX_BODY_BYTES).andExpect(status().isBadRequest());
    }

    /** Rejected before authentication: an oversized body is never read, even without a token. */
    @Test
    void limitAppliesBeforeAuthentication() throws Exception {
        assertApiError(
                mockMvc.perform(post("/api/v1/_probe/validated")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body(RequestBodySizeLimitFilter.MAX_BODY_BYTES + 1))),
                413,
                "PAYLOAD_TOO_LARGE");
    }

    private ResultActions send(long size) throws Exception {
        return mockMvc.perform(post("/api/v1/_probe/validated")
                .header("Authorization", bearer(userId))
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(size)));
    }

    private static byte[] body(long size) {
        byte[] body = new byte[(int) size];
        Arrays.fill(body, (byte) ' ');
        return body;
    }
}
