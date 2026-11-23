package com.proxycare.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.proxycare.support.AppUserRow;
import com.proxycare.support.IntegrationTest;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

/** Constraints on the app_users table from V6__app_users.sql. Value rules live in the DTO, not here. */
class AppUsersConstraintTest extends IntegrationTest {

    private static final String PHONE = "+919876543210";
    private static final String NAME = "Rahul Sharma";
    private static final String ADDRESS = "Flat 12, Sunrise Apartments, Kothrud, Pune 411038";

    @Autowired
    JdbcTemplate jdbcTemplate;

    private final UUID profileId = UUID.randomUUID();

    @Test
    void validAppUserInsertsWithoutAge() {
        testDb.insertProfile(profileId, PHONE, "USER");

        UUID appUserId = testDb.insertAppUser(profileId, NAME, "MALE", null, ADDRESS);

        AppUserRow appUserRow = testDb.appUserOf(profileId);
        assertThat(appUserRow.id()).isEqualTo(appUserId);
        assertThat(appUserRow.age()).isNull();
        assertThat(testDb.count("app_users")).isEqualTo(1);
    }

    @Test
    void idIsGeneratedAndVersionStartsAtZero() {
        testDb.insertProfile(profileId, PHONE, "USER");

        UUID appUserId = testDb.insertAppUser(profileId, NAME, "FEMALE", 34, ADDRESS);

        assertThat(appUserId).isNotNull();
        assertThat(jdbcTemplate.queryForObject("select version from app_users where id = ?", Long.class, appUserId))
                .isZero();
    }

    @Test
    void secondAppUserForTheSameProfileFails() {
        testDb.insertProfile(profileId, PHONE, "USER");
        testDb.insertAppUser(profileId, NAME, "MALE", 34, ADDRESS);

        assertThatThrownBy(() -> testDb.insertAppUser(profileId, "Priya Nair", "FEMALE", null, ADDRESS))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void appUserForAnUnknownProfileFails() {
        assertThatThrownBy(() -> testDb.insertAppUser(UUID.randomUUID(), NAME, "MALE", 34, ADDRESS))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void deletingTheProfileDeletesTheAppUser() {
        testDb.insertProfile(profileId, PHONE, "USER");
        testDb.insertAppUser(profileId, NAME, "MALE", 34, ADDRESS);

        jdbcTemplate.update("delete from profiles where id = ?", profileId);

        assertThat(testDb.count("app_users")).isZero();
    }

    @Test
    void missingRequiredColumnsFail() {
        testDb.insertProfile(profileId, PHONE, "USER");

        assertThatThrownBy(() -> testDb.insertAppUser(profileId, null, "MALE", 34, ADDRESS))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> testDb.insertAppUser(profileId, NAME, null, 34, ADDRESS))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> testDb.insertAppUser(profileId, NAME, "MALE", 34, null))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void sexOutsideTheEnumFails() {
        testDb.insertProfile(profileId, PHONE, "USER");

        assertThatThrownBy(() -> testDb.insertAppUser(profileId, NAME, "male", 34, ADDRESS))
                .isInstanceOf(DataAccessException.class)
                .hasMessageContaining("invalid input value for enum sex_type");
    }

    // Decision OQ-22: name, age and address rules are validated only in the request DTO.
    @Test
    void appUsersHaveNoCheckConstraints() {
        Long checkConstraintCount = jdbcTemplate.queryForObject(
                "select count(*) from pg_constraint where conrelid = 'public.app_users'::regclass and contype = 'c'",
                Long.class);

        assertThat(checkConstraintCount).isZero();
    }

    @Test
    void valuesTheDtoRejectsAreStillStorable() {
        testDb.insertProfile(profileId, PHONE, "USER");

        testDb.insertAppUser(profileId, "R1", "OTHER", 0, "");

        assertThat(testDb.appUserOf(profileId).age()).isZero();
    }
}
