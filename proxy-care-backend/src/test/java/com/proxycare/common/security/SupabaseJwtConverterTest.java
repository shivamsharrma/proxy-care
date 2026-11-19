package com.proxycare.common.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.common.security.CurrentUser.Role;
import java.util.EnumSet;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.jwt.Jwt;

class SupabaseJwtConverterTest {

    private final UUID id = UUID.randomUUID();
    private final Jwt jwt = Jwt.withTokenValue("token")
            .header("alg", "ES256")
            .subject(id.toString())
            .claim("phone", "919876543210")
            .build();

    @Test
    void mapsClaimsAndRoles() {
        var auth = SupabaseJwtConverter.authentication(jwt, EnumSet.of(Role.USER, Role.CARETAKER));

        assertThat(auth.getPrincipal())
                .isEqualTo(new CurrentUser(id, "919876543210", EnumSet.of(Role.USER, Role.CARETAKER)));
        assertThat(auth.getAuthorities())
                .extracting(GrantedAuthority::getAuthority)
                .containsExactlyInAnyOrder("ROLE_USER", "ROLE_CARETAKER");
        assertThat(auth.isAuthenticated()).isTrue();
    }

    @Test
    void emptyRolesAreAuthenticatedWithoutAuthorities() {
        var auth = SupabaseJwtConverter.authentication(jwt, EnumSet.noneOf(Role.class));

        assertThat(((CurrentUser) auth.getPrincipal()).roles()).isEmpty();
        assertThat(auth.getAuthorities()).isEmpty();
        assertThat(auth.isAuthenticated()).isTrue();
    }
}
