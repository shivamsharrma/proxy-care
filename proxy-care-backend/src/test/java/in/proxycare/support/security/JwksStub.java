package in.proxycare.support.security;

import static com.github.tomakehurst.wiremock.client.WireMock.get;
import static com.github.tomakehurst.wiremock.client.WireMock.okJson;
import static com.github.tomakehurst.wiremock.client.WireMock.urlPathEqualTo;

import com.github.tomakehurst.wiremock.junit5.WireMockExtension;

/**
 * Makes a WireMock server behave like a Supabase project's JWKS endpoint, so token verification
 * runs exactly as in production without contacting Supabase.
 */
public final class JwksStub {

  public static final String JWKS_PATH = "/auth/v1/.well-known/jwks.json";

  private JwksStub() {}

  /** Serves the trusted test key and returns the stub's "Supabase URL". */
  public static String serveTrustedKeys(WireMockExtension server) {
    server.stubFor(
        get(urlPathEqualTo(JWKS_PATH)).willReturn(okJson(TestJwtKeys.publicJwkSetJson())));
    return server.baseUrl();
  }

  public static String jwksUri(WireMockExtension server) {
    return server.baseUrl() + JWKS_PATH;
  }
}
