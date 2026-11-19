package com.proxycare.common.security;

import static com.proxycare.support.ProblemJsonAssert.assertProblem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class AuthorizationTest extends IntegrationTest {

    @Autowired
    JdbcTemplate jdbc;

    private final UUID userId = UUID.randomUUID();

    @Test
    void userCannotCallCaretakerEndpoint() throws Exception {
        db.insertProfile(userId, "+919876543210", "USER");

        assertProblem(
                mvc.perform(get("/api/v1/_probe/caretaker-only").header("Authorization", bearer(userId))),
                403,
                "FORBIDDEN");
    }

    @Test
    void caretakerCanCallCaretakerEndpoint() throws Exception {
        db.insertProfile(userId, "+919876543210", "CARETAKER");

        mvc.perform(get("/api/v1/_probe/caretaker-only").header("Authorization", bearer(userId)))
                .andExpect(status().isOk());
    }

    @Test
    void anotherUsersResourceIsNotFound() throws Exception {
        var owner = UUID.randomUUID();
        var thing = UUID.randomUUID();
        jdbc.update("insert into test_support.owned_things (id, user_id) values (?, ?)", thing, owner);

        mvc.perform(get("/api/v1/_probe/things/" + thing).header("Authorization", bearer(owner)))
                .andExpect(status().isOk());
        assertProblem(
                mvc.perform(get("/api/v1/_probe/things/" + thing).header("Authorization", bearer(userId))),
                404,
                "NOT_FOUND");
    }
}
