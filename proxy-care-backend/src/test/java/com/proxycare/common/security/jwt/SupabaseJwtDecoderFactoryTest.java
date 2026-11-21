package com.proxycare.common.security.jwt;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import com.proxycare.support.MutableClock;
import com.proxycare.support.TestTokens;
import java.time.Duration;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.JwtDecoder;

/** The token rules in isolation, without Spring or HTTP. */
class SupabaseJwtDecoderFactoryTest {

    private static final String PHONE = "+919876543210";

    private final MutableClock mutableClock = new MutableClock();
    private final TestTokens testTokens = new TestTokens(mutableClock);
    private final JwtProperties jwtProperties =
            new JwtProperties("https://test.supabase.co", "authenticated", Duration.ofSeconds(30));
    private final JwtDecoder jwtDecoder =
            SupabaseJwtDecoderFactory.withKeys(
                    new ImmutableJWKSet<>(testTokens.publicJwkSet()), jwtProperties, mutableClock);

    private final UUID userId = UUID.randomUUID();

    @Test
    void validTokenDecodes() {
        var jwt = jwtDecoder.decode(testTokens.forUser(userId, PHONE));

        assertThat(jwt.getSubject()).isEqualTo(userId.toString());
    }

    @Test
    void rs256IsAccepted() {
        assertThat(jwtDecoder.decode(testTokens.builder(userId, PHONE).rs256().build()).getSubject())
                .isEqualTo(userId.toString());
    }

    @Test
    void hs256IsRejected() {
        String token = testTokens.builder(userId, PHONE)
                .hs256("super-secret-jwt-token-with-at-least-32-characters-long")
                .build();

        assertThatThrownBy(() -> jwtDecoder.decode(token)).isInstanceOf(BadJwtException.class);
    }

    @Test
    void nonUuidSubjectIsRejected() {
        String token = testTokens.builder(userId, PHONE).subject("not-a-uuid").build();

        assertThatThrownBy(() -> jwtDecoder.decode(token)).isInstanceOf(BadJwtException.class);
    }

    @Test
    void wrongIssuerIsRejected() {
        String token = testTokens.builder(userId, PHONE).issuer("https://other.supabase.co/auth/v1").build();

        assertThatThrownBy(() -> jwtDecoder.decode(token)).isInstanceOf(BadJwtException.class);
    }

    @Test
    void wrongAudienceIsRejected() {
        String token = testTokens.builder(userId, PHONE).audience("anon").build();

        assertThatThrownBy(() -> jwtDecoder.decode(token)).isInstanceOf(BadJwtException.class);
    }

    @Test
    void expiryUsesTheInjectedClockAndSkew() {
        String token = testTokens.forUser(userId, PHONE);

        mutableClock.advance(Duration.ofHours(1).plusSeconds(29));
        assertThat(jwtDecoder.decode(token).getSubject()).isEqualTo(userId.toString());

        mutableClock.advance(Duration.ofSeconds(2));
        assertThatThrownBy(() -> jwtDecoder.decode(token)).isInstanceOf(BadJwtException.class);
    }
}
