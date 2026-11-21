package com.proxycare.features.profile.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.common.security.authorization.Role;
import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

class ProfileRoleProviderTest extends IntegrationTest {

    @Autowired
    ProfileRoleProvider profileRoleProvider;

    private final UUID userId = UUID.randomUUID();

    @Test
    void readsEveryRoleOfTheProfile() {
        testDb.insertProfile(userId, "+919876543210", "USER", "CARETAKER");

        assertThat(profileRoleProvider.findRoles(userId)).containsExactlyInAnyOrder(Role.USER, Role.CARETAKER);
    }

    @Test
    void noProfileMeansNoRoles() {
        assertThat(profileRoleProvider.findRoles(userId)).isEmpty();
    }

    @Test
    void anotherUsersRolesAreNotReturned() {
        testDb.insertProfile(UUID.randomUUID(), "+919876543211", "ADMIN");

        assertThat(profileRoleProvider.findRoles(userId)).isEmpty();
    }
}
