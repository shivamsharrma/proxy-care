package com.proxycare.common.security.config;

import static com.proxycare.support.ApiErrorAssert.assertApiError;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

/** Role checks, ownership and the identity provider, through the AuthProbeController endpoints. */
class AuthorizationTest extends IntegrationTest {

    @Autowired
    JdbcTemplate jdbcTemplate;

    private final UUID userId = UUID.randomUUID();

    @Test
    void userWithoutTheRoleIsDenied() throws Exception {
        testDb.insertProfile(userId, "+919876543210", "USER");

        assertApiError(
                mockMvc.perform(get("/api/v1/_probe/caretaker-only").header("Authorization", bearer(userId))),
                403,
                "ACCESS_DENIED");
    }

    @Test
    void userWithoutAProfileIsDenied() throws Exception {
        assertApiError(
                mockMvc.perform(get("/api/v1/_probe/caretaker-only").header("Authorization", bearer(userId))),
                403,
                "ACCESS_DENIED");
    }

    @Test
    void userWithTheRoleIsAllowed() throws Exception {
        testDb.insertProfile(userId, "+919876543210", "CARETAKER");

        mockMvc.perform(get("/api/v1/_probe/caretaker-only").header("Authorization", bearer(userId)))
                .andExpect(status().isOk());
    }

    @Test
    void roleChangeAppliesOnTheNextRequest() throws Exception {
        testDb.insertProfile(userId, "+919876543210", "USER");
        String auth = bearer(userId);
        jdbcTemplate.update("update profiles set roles = '{USER,CARETAKER}'::text[] where id = ?", userId);

        mockMvc.perform(get("/api/v1/_probe/caretaker-only").header("Authorization", auth))
                .andExpect(status().isOk());
    }

    @Test
    void anotherUsersResourceIsNotFound() throws Exception {
        UUID owner = UUID.randomUUID();
        UUID thing = UUID.randomUUID();
        jdbcTemplate.update("insert into test_support.owned_things (id, user_id) values (?, ?)", thing, owner);

        mockMvc.perform(get("/api/v1/_probe/things/" + thing).header("Authorization", bearer(owner)))
                .andExpect(status().isOk());
        assertApiError(
                mockMvc.perform(get("/api/v1/_probe/things/" + thing).header("Authorization", bearer(userId))),
                404,
                "RESOURCE_NOT_FOUND");
    }

    @Test
    void identityProviderSeesTheCaller() throws Exception {
        testDb.insertProfile(userId, "+919876543210", "CARETAKER");

        mockMvc.perform(get("/api/v1/_probe/whoami").header("Authorization", bearer(userId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(userId.toString()))
                .andExpect(jsonPath("$.caretaker").value(true));
    }
}
