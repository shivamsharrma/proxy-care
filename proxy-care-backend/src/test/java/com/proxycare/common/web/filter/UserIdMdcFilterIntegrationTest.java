package com.proxycare.common.web.filter;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** The filter runs after Spring Security in the real chain, so controller log lines carry the caller. */
class UserIdMdcFilterIntegrationTest extends IntegrationTest {

    @Test
    void controllerLogsCarryTheAuthenticatedUserId() throws Exception {
        UUID userId = UUID.randomUUID();

        mockMvc.perform(get("/api/v1/_probe/log-user-id").header("Authorization", bearer(userId)))
                .andExpect(content().string(userId.toString()));
    }
}
