package com.proxycare.common.security;

import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class SecurityHeadersTest extends IntegrationTest {

    @Test
    void meResponseHasNoStoreAndDefaultSecurityHeaders() throws Exception {
        mvc.perform(get("/api/v1/me").header("Authorization", bearer(UUID.randomUUID())))
                .andExpect(status().isOk())
                .andExpect(header().string("Cache-Control", containsString("no-store")))
                .andExpect(header().string("X-Content-Type-Options", "nosniff"))
                .andExpect(header().string("X-Frame-Options", "DENY"))
                .andExpect(header().doesNotExist("Server"));
    }
}
