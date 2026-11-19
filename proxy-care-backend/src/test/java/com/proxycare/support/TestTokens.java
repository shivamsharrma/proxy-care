package com.proxycare.support;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.JWSSigner;
import com.nimbusds.jose.crypto.ECDSASigner;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.Curve;
import com.nimbusds.jose.jwk.ECKey;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jose.jwk.gen.ECKeyGenerator;
import com.nimbusds.jose.jwk.gen.RSAKeyGenerator;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import java.util.UUID;

/**
 * Mints Supabase-style access tokens. Keys are generated once per test JVM: ES256 (P-256, Supabase's
 * default asymmetric key) and RS256. Times come from the injected clock, so tokens follow MutableClock.
 */
public class TestTokens {

    public static final String ISSUER = "https://test.supabase.co/auth/v1";
    public static final String AUDIENCE = "authenticated";

    private static final ECKey EC_KEY = ecKey("test-es256");
    private static final RSAKey RSA_KEY = rsaKey("test-rs256");
    // Same kid as the trusted EC key, so the decoder finds a key and the signature check fails.
    private static final ECKey OTHER_EC_KEY = ecKey("test-es256");

    private final Clock clock;

    public TestTokens(Clock clock) {
        this.clock = clock;
    }

    /** A valid ES256 token for the user, expiring one hour after the clock's now. */
    public String forUser(UUID id, String phone) {
        return builder(id, phone).build();
    }

    /** Starts from a valid token; each builder method breaks or changes one property. */
    public Builder builder(UUID id, String phone) {
        return new Builder(id, phone);
    }

    /** Public halves of both trusted keys, for building a decoder through the same JWKSource path as prod. */
    public JWKSet publicJwkSet() {
        return new JWKSet(List.of(EC_KEY.toPublicJWK(), RSA_KEY.toPublicJWK()));
    }

    public final class Builder {

        private final UUID id;
        private final String phone;
        private String issuer = ISSUER;
        private String audience = AUDIENCE;
        private boolean expired;
        private boolean rs256;
        private boolean otherKey;

        private Builder(UUID id, String phone) {
            this.id = id;
            this.phone = phone;
        }

        /** Issued two hours ago, so it expired one hour ago. */
        public Builder expired() {
            expired = true;
            return this;
        }

        public Builder issuer(String issuer) {
            this.issuer = issuer;
            return this;
        }

        public Builder audience(String audience) {
            this.audience = audience;
            return this;
        }

        public Builder signedWithOtherKey() {
            otherKey = true;
            return this;
        }

        public Builder rs256() {
            rs256 = true;
            return this;
        }

        public String build() {
            Instant iat = expired ? clock.instant().minus(Duration.ofHours(2)) : clock.instant();
            var claims = new JWTClaimsSet.Builder()
                    .subject(id.toString())
                    .claim("phone", phone)
                    .claim("role", "authenticated")
                    .issuer(issuer)
                    .audience(audience)
                    .issueTime(Date.from(iat))
                    .expirationTime(Date.from(iat.plus(Duration.ofHours(1))))
                    .build();
            try {
                JWSSigner signer;
                JWSHeader header;
                if (rs256) {
                    signer = new RSASSASigner(RSA_KEY);
                    header = new JWSHeader.Builder(JWSAlgorithm.RS256).keyID(RSA_KEY.getKeyID()).build();
                } else {
                    var key = otherKey ? OTHER_EC_KEY : EC_KEY;
                    signer = new ECDSASigner(key);
                    header = new JWSHeader.Builder(JWSAlgorithm.ES256).keyID(key.getKeyID()).build();
                }
                var jwt = new SignedJWT(header, claims);
                jwt.sign(signer);
                return jwt.serialize();
            } catch (JOSEException e) {
                throw new IllegalStateException(e);
            }
        }
    }

    private static ECKey ecKey(String kid) {
        try {
            return new ECKeyGenerator(Curve.P_256).keyID(kid).generate();
        } catch (JOSEException e) {
            throw new IllegalStateException(e);
        }
    }

    private static RSAKey rsaKey(String kid) {
        try {
            return new RSAKeyGenerator(2048).keyID(kid).generate();
        } catch (JOSEException e) {
            throw new IllegalStateException(e);
        }
    }
}
