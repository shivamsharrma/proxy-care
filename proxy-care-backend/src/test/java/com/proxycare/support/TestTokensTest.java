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

    private final MutableClock clock = new MutableClock();
    private final TestTokens tokens = new TestTokens(clock);
    private final NimbusJwtDecoder decoder = decoder();

    private NimbusJwtDecoder decoder() {
        var decoder = NimbusJwtDecoder.withJwkSource(new ImmutableJWKSet<>(tokens.publicJwkSet()))
                .jwsAlgorithms(algs -> {
                    algs.add(SignatureAlgorithm.ES256);
                    algs.add(SignatureAlgorithm.RS256);
                })
                .build();
        // Without the test clock Nimbus would check exp against real time, and the
        // January 2026 tokens would count as expired.
        var timestamps = new JwtTimestampValidator();
        timestamps.setClock(clock);
        decoder.setJwtValidator(timestamps);
        return decoder;
    }

    @Test
    void forUserTokenDecodesWithExpectedClaims() {
        var id = UUID.randomUUID();

        var jwt = decoder.decode(tokens.forUser(id, "+919876543210"));

        assertThat(jwt.getHeaders()).containsEntry("alg", "ES256");
        assertThat(jwt.getSubject()).isEqualTo(id.toString());
        assertThat(jwt.getClaimAsString("phone")).isEqualTo("+919876543210");
        assertThat(jwt.getClaimAsString("role")).isEqualTo("authenticated");
        assertThat(jwt.getIssuer().toString()).isEqualTo("https://test.supabase.co/auth/v1");
        assertThat(jwt.getAudience()).containsExactly("authenticated");
        assertThat(jwt.getIssuedAt()).isEqualTo(clock.instant());
        assertThat(jwt.getExpiresAt()).isEqualTo(clock.instant().plus(Duration.ofHours(1)));
    }

    @Test
    void rs256TokenDecodes() {
        var jwt = decoder.decode(tokens.builder(UUID.randomUUID(), "+919876543210").rs256().build());

        assertThat(jwt.getHeaders()).containsEntry("alg", "RS256");
    }

    @Test
    void expiredTokenIsRejectedByTimestampValidator() {
        var token = tokens.builder(UUID.randomUUID(), "+919876543210").expired().build();

        assertThatThrownBy(() -> decoder.decode(token)).isInstanceOf(JwtValidationException.class);
    }

    @Test
    void tokenSignedWithOtherKeyFailsToDecode() {
        var token = tokens.builder(UUID.randomUUID(), "+919876543210").signedWithOtherKey().build();

        assertThatThrownBy(() -> decoder.decode(token)).isInstanceOf(BadJwtException.class);
    }
}
