package com.proxycare.common.security.identity;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.proxycare.common.security.authorization.Role;
import java.util.EnumSet;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class AuthenticatedUserTest {

    private final UUID userId = UUID.randomUUID();

    @Test
    void rolesAreCopiedAndImmutable() {
        EnumSet<Role> roles = EnumSet.of(Role.USER);
        AuthenticatedUser authenticatedUser = new AuthenticatedUser(userId, "+919876543210", roles);

        roles.add(Role.ADMIN);

        assertThat(authenticatedUser.roles()).containsExactly(Role.USER);
        assertThatThrownBy(() -> authenticatedUser.roles().add(Role.ADMIN))
                .isInstanceOf(UnsupportedOperationException.class);
    }

    @Test
    void nullRolesMeanNoRoles() {
        AuthenticatedUser authenticatedUser = new AuthenticatedUser(userId, null, null);

        assertThat(authenticatedUser.roles()).isEmpty();
        assertThat(authenticatedUser.hasRole(Role.USER)).isFalse();
    }

    @Test
    void hasRole() {
        AuthenticatedUser authenticatedUser = new AuthenticatedUser(userId, null, EnumSet.of(Role.CARETAKER));

        assertThat(authenticatedUser.hasRole(Role.CARETAKER)).isTrue();
        assertThat(authenticatedUser.hasRole(Role.ADMIN)).isFalse();
    }

    @Test
    void userIdIsRequired() {
        assertThatThrownBy(() -> new AuthenticatedUser(null, null, null)).isInstanceOf(NullPointerException.class);
    }
}
