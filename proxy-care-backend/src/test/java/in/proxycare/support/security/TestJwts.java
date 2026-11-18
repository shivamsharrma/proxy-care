package in.proxycare.support.security;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JOSEObjectType;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.ECDSASigner;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jose.jwk.ECKey;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;

/**
 * Builds access tokens shaped like Supabase Auth's, for authentication tests.
 *
 * <p>Start from {@link #valid} and change one thing per test, so each security test states exactly
 * what is wrong with its token:
 *
 * <pre>{@code
 * String expired = TestJwts.valid(supabaseUrl, subject, clock.instant())
 *     .expiresAt(clock.instant().minusSeconds(60))
 *     .encode();
 * }</pre>
 */
public final class TestJwts {

  /** The audience Supabase puts in user access tokens. */
  public static final String AUTHENTICATED = "authenticated";

  /** Lifetime of a valid token; Supabase's default is one hour. */
  public static final Duration LIFETIME = Duration.ofHours(1);

  private TestJwts() {}

  /** A token the backend must accept: right issuer, audience, role, key and validity window. */
  public static Builder valid(String supabaseUrl, UUID subject, Instant now) {
    return new Builder()
        .issuer(issuerFor(supabaseUrl))
        .audience(AUTHENTICATED)
        .role(AUTHENTICATED)
        .subject(subject)
        .issuedAt(now)
        .expiresAt(now.plus(LIFETIME))
        .anonymous(false);
  }

  /** Supabase's issuer: the project URL plus {@code /auth/v1}. */
  public static String issuerFor(String supabaseUrl) {
    return supabaseUrl + "/auth/v1";
  }

  public static final class Builder {

    private final Map<String, Object> claims = new LinkedHashMap<>();
    private ECKey signingKey = TestJwtKeys.trusted();
    private boolean sharedSecret;

    private Builder() {}

    public Builder issuer(String issuer) {
      return claim("iss", issuer);
    }

    public Builder audience(String... audience) {
      return claim("aud", List.of(audience));
    }

    public Builder subject(UUID subject) {
      return claim("sub", subject == null ? null : subject.toString());
    }

    /** Supabase's {@code role} claim: authenticated, anon or service_role. */
    public Builder role(String role) {
      return claim("role", role);
    }

    public Builder issuedAt(Instant issuedAt) {
      return claim("iat", Date.from(issuedAt));
    }

    public Builder expiresAt(Instant expiresAt) {
      return claim("exp", Date.from(expiresAt));
    }

    public Builder notBefore(Instant notBefore) {
      return claim("nbf", Date.from(notBefore));
    }

    public Builder anonymous(boolean anonymous) {
      return claim("is_anonymous", anonymous);
    }

    /** Sets a claim; {@code null} removes it. */
    public Builder claim(String name, Object value) {
      if (value == null) {
        claims.remove(name);
      } else {
        claims.put(name, value);
      }
      return this;
    }

    /** Signs with {@code key} (ES256) instead of the trusted test key. */
    public Builder signedWith(ECKey key) {
      this.signingKey = Objects.requireNonNull(key, "key");
      this.sharedSecret = false;
      return this;
    }

    /** Signs with HS256 and a random secret, like Supabase's legacy JWT secret. */
    public Builder signedWithSharedSecret() {
      this.sharedSecret = true;
      return this;
    }

    public String encode() {
      JWTClaimsSet.Builder set = new JWTClaimsSet.Builder();
      claims.forEach(set::claim);
      try {
        if (sharedSecret) {
          byte[] secret = new byte[32];
          new SecureRandom().nextBytes(secret);
          SignedJWT jwt = new SignedJWT(header(JWSAlgorithm.HS256, null), set.build());
          jwt.sign(new MACSigner(secret));
          return jwt.serialize();
        }
        SignedJWT jwt =
            new SignedJWT(header(JWSAlgorithm.ES256, signingKey.getKeyID()), set.build());
        jwt.sign(new ECDSASigner(signingKey));
        return jwt.serialize();
      } catch (JOSEException e) {
        throw new IllegalStateException("Cannot sign test token", e);
      }
    }

    private static JWSHeader header(JWSAlgorithm algorithm, String keyId) {
      return new JWSHeader.Builder(algorithm).type(JOSEObjectType.JWT).keyID(keyId).build();
    }
  }
}
