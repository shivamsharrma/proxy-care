package com.proxycare.common.security.jwt;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.common.security.authorization.Role;
import com.proxycare.common.security.identity.AuthenticatedPrincipal;
import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
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

        var auth = supabaseJwtAuthenticationConverter.convert(jwt(userId));

        assertThat(auth.isAuthenticated()).isTrue();
        assertThat(auth.getPrincipal()).isInstanceOfSatisfying(AuthenticatedPrincipal.class, principal -> {
            assertThat(principal.userId()).isEqualTo(userId);
            assertThat(principal.phone()).isEqualTo("919876543210");
            assertThat(principal.roles()).containsExactlyInAnyOrder(Role.USER, Role.CARETAKER);
        });
        assertThat(auth.getAuthorities())
                .extracting(GrantedAuthority::getAuthority)
                .containsExactlyInAnyOrder("ROLE_USER", "ROLE_CARETAKER");
    }

    @Test
    void userWithoutProfileIsAuthenticatedWithNoRoles() {
        var auth = supabaseJwtAuthenticationConverter.convert(jwt(userId));

        assertThat(auth.isAuthenticated()).isTrue();
        assertThat(((AuthenticatedPrincipal) auth.getPrincipal()).roles()).isEmpty();
        assertThat(auth.getAuthorities()).isEmpty();
    }

    @Test
    void keepsTheJwtAsCredentials() {
        var jwt = jwt(userId);

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
