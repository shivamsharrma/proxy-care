package in.proxycare.support.security;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import in.proxycare.support.TestIds;
import java.util.Set;
import java.util.UUID;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

/**
 * An authenticated caller for MockMvc tests. {@link #asRequest()} puts an already-verified JWT
 * authentication on the request, so API tests focus on authorization; token verification itself is
 * tested with {@link TestJwts}.
 *
 * @param accountId the backend account id (what the application uses internally)
 * @param authUserId the Supabase user id (the token's {@code sub})
 * @param roles backend roles, without the {@code ROLE_} prefix
 */
public record TestUser(UUID accountId, UUID authUserId, Set<String> roles) {

  public static final String USER = "USER";
  public static final String CARETAKER = "CARETAKER";

  public TestUser {
    roles = Set.copyOf(roles);
  }

  public static TestUser user(int number) {
    return withRoles(number, USER);
  }

  public static TestUser caretaker(int number) {
    return withRoles(number, CARETAKER);
  }

  /** One person holding both roles, which the product allows. */
  public static TestUser userAndCaretaker(int number) {
    return withRoles(number, USER, CARETAKER);
  }

  /** Authenticated but with no backend role yet (for example, mid-onboarding). */
  public static TestUser withoutRoles(int number) {
    return withRoles(number);
  }

  private static TestUser withRoles(int number, String... roles) {
    return new TestUser(TestIds.account(number), TestIds.authUser(number), Set.of(roles));
  }

  public RequestPostProcessor asRequest() {
    return jwt()
        .jwt(token ->
            token
                .subject(authUserId.toString())
                .audience(Set.of(TestJwts.AUTHENTICATED))
                .claim("role", TestJwts.AUTHENTICATED))
        .authorities(
            roles.stream()
                .<GrantedAuthority>map(role -> new SimpleGrantedAuthority("ROLE_" + role))
                .toList());
  }
}
