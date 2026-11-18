package in.proxycare.support.security;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.jwk.Curve;
import com.nimbusds.jose.jwk.ECKey;
import com.nimbusds.jose.jwk.JWKSet;
import com.nimbusds.jose.jwk.gen.ECKeyGenerator;

/**
 * ES256 signing keys for tests, generated once per test JVM. No key material is stored in the
 * repository and nothing here is trusted outside tests.
 *
 * <p>Supabase signs access tokens with ES256 and publishes the public keys as a JWKS (ADR 0004);
 * {@link JwksStub} serves {@link #publicJwkSetJson()} the same way.
 */
public final class TestJwtKeys {

  public static final String KEY_ID = "proxycare-test-key";

  private static final ECKey TRUSTED = generate();

  /** Same key id as the trusted key, different key: a forged signature, not an unknown kid. */
  private static final ECKey FORGED = generate();

  private TestJwtKeys() {}

  /** The key whose public half the test JWKS publishes. */
  public static ECKey trusted() {
    return TRUSTED;
  }

  /** A key the JWKS does not publish, presented under the trusted key id. */
  public static ECKey forged() {
    return FORGED;
  }

  public static String publicJwkSetJson() {
    return new JWKSet(TRUSTED.toPublicJWK()).toString();
  }

  private static ECKey generate() {
    try {
      return new ECKeyGenerator(Curve.P_256).keyID(KEY_ID).generate();
    } catch (JOSEException e) {
      throw new IllegalStateException("Cannot generate a test EC key", e);
    }
  }
}
