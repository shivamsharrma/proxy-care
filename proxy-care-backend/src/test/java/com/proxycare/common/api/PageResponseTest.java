package com.proxycare.common.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** The probe endpoint lists 250 items. */
class PageResponseTest extends IntegrationTest {

    private final UUID userId = UUID.randomUUID();

    @Test
    void oversizedPageIsCappedAt100() throws Exception {
        mockMvc.perform(get("/api/v1/_probe/items?size=500").header("Authorization", bearer(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(100))
                .andExpect(jsonPath("$.size").value(100))
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.totalElements").value(250))
                .andExpect(jsonPath("$.totalPages").value(3));
    }

    @Test
    void defaultPageSizeIs20() throws Exception {
        mockMvc.perform(get("/api/v1/_probe/items").header("Authorization", bearer(userId)))
                .andExpect(jsonPath("$.items.length()").value(20))
                .andExpect(jsonPath("$.size").value(20))
                .andExpect(jsonPath("$.totalPages").value(13));
    }

    @Test
    void lastPageIsPartial() throws Exception {
        mockMvc.perform(get("/api/v1/_probe/items?page=2&size=100").header("Authorization", bearer(userId)))
                .andExpect(jsonPath("$.items.length()").value(50))
                .andExpect(jsonPath("$.page").value(2))
                .andExpect(jsonPath("$.totalPages").value(3));
    }
}
