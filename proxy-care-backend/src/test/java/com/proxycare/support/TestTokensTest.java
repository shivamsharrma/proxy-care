package com.proxycare.support;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.nimbusds.jose.jwk.source.ImmutableJWKSet;
import java.time.Duration;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.JwtValidationException;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

class TestTokensTest {

    private final MutableClock mutableClock = new MutableClock();
    private final TestTokens testTokens = new TestTokens(mutableClock);
    private final NimbusJwtDecoder nimbusJwtDecoder = decoder();

    private NimbusJwtDecoder decoder() {
        var nimbusJwtDecoder = NimbusJwtDecoder.withJwkSource(new ImmutableJWKSet<>(testTokens.publicJwkSet()))
                .jwsAlgorithms(algs -> {
                    algs.add(SignatureAlgorithm.ES256);
                    algs.add(SignatureAlgorithm.RS256);
                })
                .build();
        // Without the test clock Nimbus would check exp against real time, and the
        // January 2026 tokens would count as expired.
        var timestamps = new JwtTimestampValidator();
        timestamps.setClock(mutableClock);
        nimbusJwtDecoder.setJwtValidator(timestamps);
        return nimbusJwtDecoder;
    }

    @Test
    void forUserTokenDecodesWithExpectedClaims() {
        var id = UUID.randomUUID();

        var jwt = nimbusJwtDecoder.decode(testTokens.forUser(id, "+919876543210"));

        assertThat(jwt.getHeaders()).containsEntry("alg", "ES256");
        assertThat(jwt.getSubject()).isEqualTo(id.toString());
        assertThat(jwt.getClaimAsString("phone")).isEqualTo("+919876543210");
        assertThat(jwt.getClaimAsString("role")).isEqualTo("authenticated");
        assertThat(jwt.getIssuer().toString()).isEqualTo("https://test.supabase.co/auth/v1");
        assertThat(jwt.getAudience()).containsExactly("authenticated");
        assertThat(jwt.getIssuedAt()).isEqualTo(mutableClock.instant());
        assertThat(jwt.getExpiresAt()).isEqualTo(mutableClock.instant().plus(Duration.ofHours(1)));
    }

    @Test
    void rs256TokenDecodes() {
        var jwt = nimbusJwtDecoder.decode(testTokens.builder(UUID.randomUUID(), "+919876543210").rs256().build());

        assertThat(jwt.getHeaders()).containsEntry("alg", "RS256");
    }

    @Test
    void expiredTokenIsRejectedByTimestampValidator() {
        var token = testTokens.builder(UUID.randomUUID(), "+919876543210").expired().build();

        assertThatThrownBy(() -> nimbusJwtDecoder.decode(token)).isInstanceOf(JwtValidationException.class);
    }

    @Test
    void tokenSignedWithOtherKeyFailsToDecode() {
        var token = testTokens.builder(UUID.randomUUID(), "+919876543210").signedWithOtherKey().build();

        assertThatThrownBy(() -> nimbusJwtDecoder.decode(token)).isInstanceOf(BadJwtException.class);
    }
}
