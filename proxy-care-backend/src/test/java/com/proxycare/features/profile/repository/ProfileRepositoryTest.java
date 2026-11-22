package com.proxycare.features.profile.repository;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.proxycare.common.security.authorization.Role;
import com.proxycare.features.profile.entity.ProfileEntity;
import com.proxycare.features.profile.enums.PreferredLanguage;
import com.proxycare.support.IntegrationTest;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;

class ProfileRepositoryTest extends IntegrationTest {

    @Autowired
    ProfileRepository profileRepository;

    // The id is assigned, so only the null version tells Spring Data the entity is new. A new one must be
    // inserted (and hit the primary key) rather than merged over a row another first sign-in just created.
    @Test
    void savingANewProfileEntityForAnExistingIdHitsThePrimaryKeyAndKeepsTheExistingRow() {
        UUID id = UUID.randomUUID();
        testDb.insertProfile(id, "+919876543210", "CARETAKER");

        ProfileEntity profileEntity = new ProfileEntity();
        profileEntity.setId(id);
        profileEntity.setPhone("+919800000000");
        profileEntity.setRoles(Set.of(Role.USER));
        profileEntity.setPreferredLanguage(PreferredLanguage.HI);

        assertThatThrownBy(() -> profileRepository.saveAndFlush(profileEntity))
                .isInstanceOf(DataIntegrityViolationException.class);

        assertThat(testDb.rolesOf(id)).containsExactly("CARETAKER");
        assertThat(testDb.phoneOf(id)).isEqualTo("+919876543210");
        assertThat(testDb.preferredLanguageOf(id)).isEqualTo("EN");
        assertThat(testDb.count("profiles")).isEqualTo(1);
    }
}
