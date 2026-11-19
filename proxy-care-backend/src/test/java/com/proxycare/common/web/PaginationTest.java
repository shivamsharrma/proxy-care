package com.proxycare.common.web;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** The probe endpoint lists 250 items. */
class PaginationTest extends IntegrationTest {

    private final UUID userId = UUID.randomUUID();

    @Test
    void oversizedPageIsCappedAt100() throws Exception {
        mvc.perform(get("/api/v1/_probe/items?size=500").header("Authorization", bearer(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(100))
                .andExpect(jsonPath("$.size").value(100))
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.hasNext").value(true));
    }

    @Test
    void defaultPageSizeIs20() throws Exception {
        mvc.perform(get("/api/v1/_probe/items").header("Authorization", bearer(userId)))
                .andExpect(jsonPath("$.items.length()").value(20))
                .andExpect(jsonPath("$.size").value(20))
                .andExpect(jsonPath("$.hasNext").value(true));
    }

    @Test
    void lastPageHasNoNext() throws Exception {
        mvc.perform(get("/api/v1/_probe/items?page=2&size=100").header("Authorization", bearer(userId)))
                .andExpect(jsonPath("$.items.length()").value(50))
                .andExpect(jsonPath("$.page").value(2))
                .andExpect(jsonPath("$.hasNext").value(false));
    }
}
