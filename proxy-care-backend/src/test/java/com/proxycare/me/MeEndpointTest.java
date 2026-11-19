package com.proxycare.me;

import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.ResultActions;

class MeEndpointTest extends IntegrationTest {

    private static final String PHONE = "+919876543210";
    private final UUID userId = UUID.randomUUID();

    @Test
    void noProfileYet() throws Exception {
        me().andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId.toString()))
                .andExpect(jsonPath("$.roles").isEmpty())
                .andExpect(jsonPath("$.preferredLanguage").isEmpty());
    }

    @Test
    void userProfile() throws Exception {
        db.insertProfile(userId, PHONE, "USER");

        me().andExpect(jsonPath("$.roles", containsInAnyOrder("USER")))
                .andExpect(jsonPath("$.preferredLanguage").value("en"));
    }

    @Test
    void userAndCaretakerProfile() throws Exception {
        db.insertProfile(userId, PHONE, "USER", "CARETAKER");

        me().andExpect(jsonPath("$.roles", containsInAnyOrder("USER", "CARETAKER")));
    }

    @Test
    void phoneIsMasked() throws Exception {
        me().andExpect(jsonPath("$.phone").value("+91******3210"));
    }

    private ResultActions me() throws Exception {
        return mvc.perform(get("/api/v1/me").header("Authorization", "Bearer " + tokens.forUser(userId, PHONE)));
    }
}
