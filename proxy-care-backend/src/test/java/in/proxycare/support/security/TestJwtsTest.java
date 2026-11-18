package in.proxycare.support.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.github.tomakehurst.wiremock.junit5.WireMockExtension;
import in.proxycare.support.MutableClock;
import in.proxycare.support.TestIds;
import in.proxycare.support.WireMockSupport;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.RegisterExtension;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtTimestampValidator;
import org.springframework.security.oauth2.jwt.JwtValidationException;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

/**
 * Proves each {@link TestJwts} fixture is accepted or rejected for the intended reason, by a
 * reference decoder configured with the rules of ADR 0004 and keys served from a WireMock JWKS.
 *
 * <p>The reference decoder is test code. The authentication milestone implements the production
 * decoder and reuses these fixtures and scenarios against it.
 */
class TestJwtsTest {

  @RegisterExtension static final WireMockExtension supabase = WireMockSupport.newServer();

  private final MutableClock clock = new MutableClock();
  private final UUID subject = TestIds.authUser(1);
  private String supabaseUrl;
  private NimbusJwtDecoder decoder;

  @BeforeEach
  void startSupabaseStub() {
    supabaseUrl = JwksStub.serveTrustedKeys(supabase);
    decoder = referenceDecoder(JwksStub.jwksUri(supabase), TestJwts.issuerFor(supabaseUrl));
  }

  @Test
  void acceptsAValidToken() {
    Jwt jwt = decoder.decode(valid().encode());

    assertThat(jwt.getSubject()).isEqualTo(subject.toString());
    assertThat(jwt.getAudience()).containsExactly(TestJwts.AUTHENTICATED);
    assertThat(jwt.getClaimAsString("role")).isEqualTo(TestJwts.AUTHENTICATED);
  }

  @Test
  void rejectsAnExpiredToken() {
    String token = valid().encode();
    clock.advance(TestJwts.LIFETIME.plus(Duration.ofMinutes(1)));

    assertThatThrownBy(() -> decoder.decode(token))
        .isInstanceOf(JwtValidationException.class)
        .hasMessageContaining("expired");
  }

  @Test
  void acceptsATokenWithinTheClockSkewAllowance() {
    String token = valid().encode();
    clock.advance(TestJwts.LIFETIME.plusSeconds(20));

    assertThat(decoder.decode(token).getSubject()).isEqualTo(subject.toString());
  }

  @Test
  void rejectsATokenThatIsNotValidYet() {
    Instant later = clock.instant().plus(Duration.ofMinutes(5));
    String token = valid().notBefore(later).encode();

    assertThatThrownBy(() -> decoder.decode(token)).isInstanceOf(JwtValidationException.class);
  }

  @Test
  void rejectsAForgedSignature() {
    String token = valid().signedWith(TestJwtKeys.forged()).encode();

    assertThatThrownBy(() -> decoder.decode(token))
        .isInstanceOf(BadJwtException.class)
        .hasMessageContaining("Invalid signature");
  }

  @Test
  void rejectsALegacySharedSecretToken() {
    String token = valid().signedWithSharedSecret().encode();

    assertThatThrownBy(() -> decoder.decode(token)).isInstanceOf(BadJwtException.class);
  }

  @Test
  void rejectsAnotherIssuer() {
    String token = valid().issuer("https://other-project.supabase.co/auth/v1").encode();

    assertThatThrownBy(() -> decoder.decode(token))
        .isInstanceOf(JwtValidationException.class)
        .hasMessageContaining("iss");
  }

  @Test
  void rejectsAnotherAudience() {
    String token = valid().audience("anon").encode();

    assertThatThrownBy(() -> decoder.decode(token))
        .isInstanceOf(JwtValidationException.class)
        .hasMessageContaining("aud");
  }

  @Test
  void rejectsAnonymousAndServiceRoleKeys() {
    for (String role : List.of("anon", "service_role")) {
      String token = valid().role(role).encode();

      assertThatThrownBy(() -> decoder.decode(token))
          .as("role %s", role)
          .isInstanceOf(JwtValidationException.class)
          .hasMessageContaining("role");
    }
  }

  private TestJwts.Builder valid() {
    return TestJwts.valid(supabaseUrl, subject, clock.instant());
  }

  /** ADR 0004's rules, expressed with Spring Security's standard validators. */
  private NimbusJwtDecoder referenceDecoder(String jwksUri, String issuer) {
    NimbusJwtDecoder nimbus =
        NimbusJwtDecoder.withJwkSetUri(jwksUri).jwsAlgorithm(SignatureAlgorithm.ES256).build();
    JwtTimestampValidator timestamps = new JwtTimestampValidator(Duration.ofSeconds(30));
    timestamps.setClock(clock);
    nimbus.setJwtValidator(
        new DelegatingOAuth2TokenValidator<>(
            timestamps,
            new JwtIssuerValidator(issuer),
            new JwtClaimValidator<List<String>>(
                "aud", audience -> audience != null && audience.contains(TestJwts.AUTHENTICATED)),
            new JwtClaimValidator<String>("role", TestJwts.AUTHENTICATED::equals)));
    return nimbus;
  }
}
