package com.proxycare.common.security.identity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.proxycare.common.security.authorization.Role;
import java.util.EnumSet;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AuthenticatedPrincipalTest {

    private final UUID userId = UUID.randomUUID();

    @Test
    void rolesAreCopiedAndImmutable() {
        var roles = EnumSet.of(Role.USER);
        var principal = new AuthenticatedPrincipal(userId, "+919876543210", roles);

        roles.add(Role.ADMIN);

        assertThat(principal.roles()).containsExactly(Role.USER);
        assertThatThrownBy(() -> principal.roles().add(Role.ADMIN)).isInstanceOf(UnsupportedOperationException.class);
    }

    @Test
    void nullRolesMeanNoRoles() {
        var principal = new AuthenticatedPrincipal(userId, null, null);

        assertThat(principal.roles()).isEmpty();
        assertThat(principal.hasRole(Role.USER)).isFalse();
    }

    @Test
    void hasRole() {
        var principal = new AuthenticatedPrincipal(userId, null, EnumSet.of(Role.CARETAKER));

        assertThat(principal.hasRole(Role.CARETAKER)).isTrue();
        assertThat(principal.hasRole(Role.ADMIN)).isFalse();
    }

    @Test
    void userIdIsRequired() {
        assertThatThrownBy(() -> new AuthenticatedPrincipal(null, null, null)).isInstanceOf(NullPointerException.class);
    }
}
