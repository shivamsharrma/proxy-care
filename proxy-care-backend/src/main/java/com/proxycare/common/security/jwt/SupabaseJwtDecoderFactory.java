package com.proxycare.common.security.jwt;

import com.nimbusds.jose.jwk.source.JWKSource;
import com.nimbusds.jose.jwk.source.JWKSourceBuilder;
import com.nimbusds.jose.proc.SecurityContext;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimNames;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

import java.net.MalformedURLException;
import java.net.URI;
import java.time.Clock;
import java.util.Collection;
import java.util.Set;
import java.util.UUID;

/**
 * Builds the decoder that verifies Supabase access tokens. The single place that decides which tokens are
 * valid: signature algorithm, issuer, audience, expiry and subject.
 */
public final class SupabaseJwtDecoderFactory {

    private SupabaseJwtDecoderFactory() {}

    /** Uses Supabase's published signing keys; fetched on first use and cached, so startup makes no network call. */
    public static JwtDecoder fromSupabaseJwks(JwtProperties properties, Clock clock) throws MalformedURLException {
        JWKSource<SecurityContext> supabaseKeys = JWKSourceBuilder
                .create(URI.create(properties.jwkSetUri()).toURL())
                .build();

        return withKeys(supabaseKeys, properties, clock);
    }

    /** Same rules with any key source; tests pass their own keys and the MutableClock. */
    public static JwtDecoder withKeys(JWKSource<SecurityContext> keys, JwtProperties properties, Clock clock) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSource(keys)
                .jwsAlgorithms(SupabaseJwtDecoderFactory::allowAsymmetricAlgorithmsOnly)
                .build();

        decoder.setJwtValidator(tokenRules(properties, clock));
        return decoder;
    }

    /** ES256 is Supabase's default key type, RS256 its alternative. Never HS256 (a shared secret) or none. */
    private static void allowAsymmetricAlgorithmsOnly(Set<SignatureAlgorithm> algorithms) {
        algorithms.add(SignatureAlgorithm.ES256);
        algorithms.add(SignatureAlgorithm.RS256);
    }

    private static OAuth2TokenValidator<Jwt> tokenRules(JwtProperties properties, Clock clock) {
        return new DelegatingOAuth2TokenValidator<>(
                notExpired(properties, clock),
                new JwtIssuerValidator(properties.issuer()),
                audienceIs(properties.audience()),
                subjectIsUuid()
        );
    }

    private static OAuth2TokenValidator<Jwt> notExpired(JwtProperties properties, Clock clock) {
        JwtTimestampValidator validator = new JwtTimestampValidator(properties.clockSkew());
        validator.setClock(clock);
        return validator;
    }

    private static OAuth2TokenValidator<Jwt> audienceIs(String expectedAudience) {
        return new JwtClaimValidator<Collection<String>>(
                JwtClaimNames.AUD,
                audience -> audience != null && audience.contains(expectedAudience));
    }

    /** The subject becomes the user id everywhere, so anything but a canonical UUID is rejected here. */
    private static OAuth2TokenValidator<Jwt> subjectIsUuid() {
        return new JwtClaimValidator<String>(JwtClaimNames.SUB, SupabaseJwtDecoderFactory::isCanonicalUuid);
    }

    private static boolean isCanonicalUuid(String value) {
        if (value == null) {
            return false;
        }
        try {
            return UUID.fromString(value).toString().equalsIgnoreCase(value);
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

}
