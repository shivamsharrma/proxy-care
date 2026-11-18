package in.proxycare.shared.security;

import static org.assertj.core.api.Assertions.assertThat;

import in.proxycare.shared.error.ErrorCode;
import in.proxycare.support.ApiAssertions;
import in.proxycare.support.IntegrationTest;
import in.proxycare.support.security.TestUser;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

/**
 * Example MockMvc test: requests go through the real security filter chain and dispatcher.
 *
 * <p>Pins today's deny-by-default chain and its problem responses (ADR 0012). The authentication
 * milestone adds JWT authentication; these tests then use {@link TestUser} for role and ownership
 * checks on real endpoints.
 */
@IntegrationTest
class SecurityFilterChainTest {

  @Autowired private MockMvcTester mvc;

  @ParameterizedTest
  @ValueSource(strings = {"/actuator/health", "/actuator/health/liveness", "/v3/api-docs"})
  void publicEndpointsNeedNoAuthentication(String path) {
    assertThat(mvc.get().uri(path)).hasStatusOk();
  }

  @Test
  void anonymousRequestsGetA401Problem() {
    var result = mvc.get().uri("/api/v1/me").exchange();

    assertThat(result).hasStatus(HttpStatus.UNAUTHORIZED);
    assertThat(result.getResponse().getHeader(HttpHeaders.WWW_AUTHENTICATE)).isEqualTo("Bearer");
    ApiAssertions.assertProblem(body(result), ErrorCode.UNAUTHENTICATED);
  }

  @ParameterizedTest
  @MethodSource("everyKindOfUser")
  void authenticatedRequestsGetA403ProblemUntilEndpointsExist(TestUser user) {
    var result = mvc.get().uri("/api/v1/me").with(user.asRequest()).exchange();

    assertThat(result).hasStatus(HttpStatus.FORBIDDEN);
    ApiAssertions.assertProblem(body(result), ErrorCode.FORBIDDEN);
  }

  @Test
  void writesAreRefusedByAuthorizationNotByCsrf() {
    // CSRF is off for the stateless bearer API: an anonymous write is 401, not a CSRF 403.
    assertThat(mvc.post().uri("/api/v1/bookings")).hasStatus(HttpStatus.UNAUTHORIZED);
    assertThat(mvc.post().uri("/api/v1/bookings").with(TestUser.user(1).asRequest()))
        .hasStatus(HttpStatus.FORBIDDEN);
  }

  private static String body(org.springframework.test.web.servlet.assertj.MvcTestResult result) {
    try {
      return result.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
    } catch (java.io.UnsupportedEncodingException e) {
      throw new IllegalStateException(e);
    }
  }

  @Test
  void createsNoSession() {
    assertThat(mvc.get().uri("/actuator/health").with(TestUser.user(1).asRequest()))
        .hasStatusOk()
        .request()
        .sessionAttributes()
        .isEmpty();
  }

  static Stream<TestUser> everyKindOfUser() {
    return Stream.of(
        TestUser.user(1),
        TestUser.caretaker(2),
        TestUser.userAndCaretaker(3),
        TestUser.withoutRoles(4));
  }
}
