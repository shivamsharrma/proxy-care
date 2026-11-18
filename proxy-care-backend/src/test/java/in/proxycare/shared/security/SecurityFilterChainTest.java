package in.proxycare.shared.security;

import static org.assertj.core.api.Assertions.assertThat;

import in.proxycare.support.IntegrationTest;
import in.proxycare.support.security.TestUser;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

/**
 * Example MockMvc test: requests go through the real security filter chain and dispatcher.
 *
 * <p>Pins today's deny-by-default chain. The authentication milestone adds JWT authentication;
 * these tests then change to 401 for anonymous callers and use {@link TestUser} for role and
 * ownership checks.
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
  void anonymousRequestsAreRefused() {
    assertThat(mvc.get().uri("/v1/me")).hasStatus(HttpStatus.FORBIDDEN);
  }

  @ParameterizedTest
  @MethodSource("everyKindOfUser")
  void authenticatedRequestsAreRefusedUntilEndpointsExist(TestUser user) {
    assertThat(mvc.get().uri("/v1/me").with(user.asRequest())).hasStatus(HttpStatus.FORBIDDEN);
  }

  @Test
  void writesAreRefused() {
    assertThat(mvc.post().uri("/v1/bookings").with(TestUser.user(1).asRequest()))
        .hasStatus(HttpStatus.FORBIDDEN);
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
