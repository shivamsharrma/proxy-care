package com.proxycare.features.profile.controller;

import static com.proxycare.support.ApiErrorAssert.assertApiError;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.ResultActions;

class ProfileControllerTest extends IntegrationTest {

    private static final String PHONE = "+919876543210";

    private final UUID userId = UUID.randomUUID();

    @Test
    void noProfileYetIsProfileNotFound() throws Exception {
        assertApiError(me(), 404, "PROFILE_NOT_FOUND");
    }

    @Test
    void returnsTheCallersProfile() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER");

        me().andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(userId.toString()))
                .andExpect(jsonPath("$.phone").value(PHONE))
                .andExpect(jsonPath("$.roles", containsInAnyOrder("USER")))
                .andExpect(jsonPath("$.preferredLanguage").value("en"));
    }

    @Test
    void returnsEveryRole() throws Exception {
        testDb.insertProfile(userId, PHONE, "USER", "CARETAKER");

        me().andExpect(jsonPath("$.roles", containsInAnyOrder("USER", "CARETAKER")));
    }

    @Test
    void neverReturnsSomeoneElsesProfile() throws Exception {
        testDb.insertProfile(UUID.randomUUID(), "+919800000000", "ADMIN");

        assertApiError(me(), 404, "PROFILE_NOT_FOUND");
    }

    @Test
    void needsAToken() throws Exception {
        assertApiError(mockMvc.perform(get("/api/v1/profile/me")), 401, "UNAUTHENTICATED");
    }

    private ResultActions me() throws Exception {
        return mockMvc.perform(get("/api/v1/profile/me")
                .header("Authorization", "Bearer " + testTokens.forUser(userId, PHONE)));
    }
}
