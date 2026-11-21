package com.proxycare.common.web.filter;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ApiCacheControlFilterTest extends IntegrationTest {

    @Test
    void apiResponseIsNoStore() throws Exception {
        mockMvc.perform(get("/api/v1/_probe/items").header("Authorization", bearer(UUID.randomUUID())))
                .andExpect(status().isOk())
                .andExpect(header().string("Cache-Control", "no-store"));
    }

    /** Runs before Spring Security, so its 401 is not cached either. */
    @Test
    void apiErrorIsNoStore() throws Exception {
        mockMvc.perform(get("/api/v1/_probe/whoami"))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string("Cache-Control", "no-store"));
    }

    /** Outside /api this filter does nothing; Spring Security's own default header stays as it is. */
    @Test
    void nonApiResponseKeepsSpringSecurityDefault() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk())
                .andExpect(header().string("Cache-Control", "no-cache, no-store, max-age=0, must-revalidate"));
    }
}
