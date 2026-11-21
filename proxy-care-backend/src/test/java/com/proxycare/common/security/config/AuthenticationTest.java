package com.proxycare.common.security.config;

import static com.proxycare.support.ApiErrorAssert.assertApiError;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.proxycare.support.IntegrationTest;
import java.time.Duration;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.ResultActions;

/** Which tokens the API accepts, checked end to end through a protected probe endpoint. */
class AuthenticationTest extends IntegrationTest {

    private static final String PHONE = "+919876543210";

    private final UUID userId = UUID.randomUUID();

    @Test
    void validEs256TokenIsAccepted() throws Exception {
        callApi(testTokens.forUser(userId, PHONE))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value(userId.toString()));
    }

    @Test
    void validRs256TokenIsAccepted() throws Exception {
        callApi(testTokens.builder(userId, PHONE).rs256().build()).andExpect(status().isOk());
    }

    @Test
    void missingTokenIsUnauthenticated() throws Exception {
        assertApiError(mockMvc.perform(get("/api/v1/_probe/whoami")), 401, "UNAUTHENTICATED")
                .andExpect(header().string("WWW-Authenticate", "Bearer"));
    }

    @Test
    void garbageTokenIsUnauthenticated() throws Exception {
        assertApiError(callApi("not-a-jwt"), 401, "UNAUTHENTICATED");
    }

    @Test
    void expiredTokenIsUnauthenticated() throws Exception {
        assertApiError(callApi(testTokens.builder(userId, PHONE).expired().build()), 401, "UNAUTHENTICATED");
    }

    @Test
    void tokenJustPastExpiryIsAcceptedWithinClockSkew() throws Exception {
        String token = testTokens.forUser(userId, PHONE);
        mutableClock.advance(Duration.ofHours(1).plusSeconds(20));

        callApi(token).andExpect(status().isOk());
    }

    @Test
    void tokenPastClockSkewIsUnauthenticated() throws Exception {
        String token = testTokens.forUser(userId, PHONE);
        mutableClock.advance(Duration.ofHours(1).plusSeconds(31));

        assertApiError(callApi(token), 401, "UNAUTHENTICATED");
    }

    @Test
    void wrongIssuerIsUnauthenticated() throws Exception {
        String token = testTokens.builder(userId, PHONE).issuer("https://evil.supabase.co/auth/v1").build();

        assertApiError(callApi(token), 401, "UNAUTHENTICATED");
    }

    @Test
    void wrongAudienceIsUnauthenticated() throws Exception {
        String token = testTokens.builder(userId, PHONE).audience("anon").build();

        assertApiError(callApi(token), 401, "UNAUTHENTICATED");
    }

    @Test
    void tokenSignedWithAnUntrustedKeyIsUnauthenticated() throws Exception {
        assertApiError(callApi(testTokens.builder(userId, PHONE).signedWithOtherKey().build()), 401, "UNAUTHENTICATED");
    }

    @Test
    void hs256TokenIsRejected() throws Exception {
        String token = testTokens.builder(userId, PHONE)
                .hs256("super-secret-jwt-token-with-at-least-32-characters-long")
                .build();

        assertApiError(callApi(token), 401, "UNAUTHENTICATED");
    }

    @Test
    void basicAuthIsNotSupported() throws Exception {
        assertApiError(
                mockMvc.perform(get("/api/v1/_probe/whoami").header("Authorization", "Basic dXNlcjpwYXNz")),
                401,
                "UNAUTHENTICATED");
    }

    private ResultActions callApi(String token) throws Exception {
        return mockMvc.perform(get("/api/v1/_probe/whoami").header("Authorization", "Bearer " + token));
    }
}
