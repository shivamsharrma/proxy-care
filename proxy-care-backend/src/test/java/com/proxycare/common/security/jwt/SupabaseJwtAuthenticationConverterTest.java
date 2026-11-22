package com.proxycare.common.security.jwt;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.common.security.authorization.Role;
import com.proxycare.common.security.identity.AuthenticatedUser;
import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.AbstractAuthenticationToken;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

/** Roles come from the database, so this runs against the real profiles table. */
class SupabaseJwtAuthenticationConverterTest extends IntegrationTest {

    @Autowired
    SupabaseJwtAuthenticationConverter supabaseJwtAuthenticationConverter;

    private final UUID userId = UUID.randomUUID();

    @Test
    void mapsIdentityFromTheTokenAndRolesFromTheProfile() {
        testDb.insertProfile(userId, "+919876543210", "USER", "CARETAKER");

        AbstractAuthenticationToken abstractAuthenticationToken = supabaseJwtAuthenticationConverter.convert(jwt(userId));

        assertThat(abstractAuthenticationToken.isAuthenticated()).isTrue();
        assertThat(abstractAuthenticationToken.getPrincipal()).isInstanceOfSatisfying(AuthenticatedUser.class, authenticatedUser -> {
            assertThat(authenticatedUser.userId()).isEqualTo(userId);
            assertThat(authenticatedUser.phone()).isEqualTo("919876543210");
            assertThat(authenticatedUser.roles()).containsExactlyInAnyOrder(Role.USER, Role.CARETAKER);
        });
        assertThat(abstractAuthenticationToken.getAuthorities())
                .extracting(GrantedAuthority::getAuthority)
                .containsExactlyInAnyOrder("ROLE_USER", "ROLE_CARETAKER");
    }

    @Test
    void userWithoutProfileIsAuthenticatedWithNoRoles() {
        AbstractAuthenticationToken abstractAuthenticationToken = supabaseJwtAuthenticationConverter.convert(jwt(userId));

        assertThat(abstractAuthenticationToken.isAuthenticated()).isTrue();
        assertThat(((AuthenticatedUser) abstractAuthenticationToken.getPrincipal()).roles()).isEmpty();
        assertThat(abstractAuthenticationToken.getAuthorities()).isEmpty();
    }

    @Test
    void keepsTheJwtAsCredentials() {
        Jwt jwt = jwt(userId);

        assertThat(supabaseJwtAuthenticationConverter.convert(jwt).getCredentials()).isSameAs(jwt);
    }

    private static Jwt jwt(UUID subject) {
        return Jwt.withTokenValue("token")
                .header("alg", "ES256")
                .subject(subject.toString())
                .claim("phone", "919876543210")
                .build();
    }
}
