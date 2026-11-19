package com.proxycare.common.security;

import static com.proxycare.support.ProblemJsonAssert.assertProblem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.time.Duration;
import java.util.UUID;
import org.junit.jupiter.api.Test;

/** Every case goes through the real decoder, validators, converter and profile lookup. */
class AuthenticationTest extends IntegrationTest {

    private static final String PHONE = "+919876543210";
    private final UUID userId = UUID.randomUUID();

    @Test
    void noToken() throws Exception {
        assertProblem(mvc.perform(get("/api/v1/me")), 401, "UNAUTHENTICATED");
    }

    @Test
    void malformedToken() throws Exception {
        assertUnauthenticated("not-a-jwt");
    }

    @Test
    void expiredToken() throws Exception {
        assertUnauthenticated(tokens.builder(userId, PHONE).expired().build());
    }

    @Test
    void wrongIssuer() throws Exception {
        assertUnauthenticated(tokens.builder(userId, PHONE).issuer("https://evil.supabase.co/auth/v1").build());
    }

    @Test
    void wrongAudience() throws Exception {
        assertUnauthenticated(tokens.builder(userId, PHONE).audience("anon").build());
    }

    @Test
    void signedByOtherKey() throws Exception {
        assertUnauthenticated(tokens.builder(userId, PHONE).signedWithOtherKey().build());
    }

    @Test
    void hs256RejectedWhenJwtSecretUnset() throws Exception {
        assertUnauthenticated(tokens.builder(userId, PHONE)
                .hs256("a-shared-secret-that-is-at-least-32-bytes")
                .build());
    }

    @Test
    void validEs256Token() throws Exception {
        mvc.perform(get("/api/v1/me").header("Authorization", "Bearer " + tokens.forUser(userId, PHONE)))
                .andExpect(status().isOk());
    }

    @Test
    void validRs256Token() throws Exception {
        mvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + tokens.builder(userId, PHONE).rs256().build()))
                .andExpect(status().isOk());
    }

    @Test
    void expiryFollowsTheClock() throws Exception {
        var token = tokens.forUser(userId, PHONE);
        mvc.perform(get("/api/v1/me").header("Authorization", "Bearer " + token)).andExpect(status().isOk());

        clock.advance(Duration.ofHours(2));

        assertUnauthenticated(token);
    }

    private void assertUnauthenticated(String token) throws Exception {
        assertProblem(mvc.perform(get("/api/v1/me").header("Authorization", "Bearer " + token)), 401, "UNAUTHENTICATED");
    }
}
