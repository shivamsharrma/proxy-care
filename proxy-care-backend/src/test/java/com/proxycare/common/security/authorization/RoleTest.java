package com.proxycare.common.security.authorization;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class RoleTest {

    @Test
    void authorityHasTheSpringRolePrefix() {
        assertThat(Role.CARETAKER.authority()).isEqualTo("ROLE_CARETAKER");
    }

    @Test
    void namesMatchTheAppRoleEnum() {
        assertThat(Role.values()).extracting(Role::name).containsExactly("USER", "CARETAKER", "ADMIN");
    }
}
