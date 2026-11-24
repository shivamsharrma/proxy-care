package com.proxycare.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.proxycare.support.IntegrationTest;
import com.proxycare.support.MutableClock;
import com.proxycare.support.PatientRow;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

/** Constraints on the patients table from V7__patients.sql. Value rules live in the DTO, not here. */
class PatientsConstraintTest extends IntegrationTest {

    private static final String PHONE = "+919876543210";
    private static final String USER_NAME = "Rahul Sharma";
    private static final String USER_ADDRESS = "Flat 12, Sunrise Apartments, Kothrud, Pune 411038";
    private static final String SURESH = "Suresh Sharma";
    private static final Instant ADDED_AT = MutableClock.DEFAULT_INSTANT;

    @Autowired
    JdbcTemplate jdbcTemplate;

    private final UUID profileId = UUID.randomUUID();
    private UUID appUserId;

    @BeforeEach
    void insertTheOwningAppUser() {
        testDb.insertProfile(profileId, PHONE, "USER");
        appUserId = testDb.insertAppUser(profileId, USER_NAME, "MALE", 34, USER_ADDRESS);
    }

    @Test
    void validPatientInsertsWithoutMobileOrHealthNotes() {
        UUID patientId = testDb.insertPatient(
                appUserId, "FATHER", SURESH, 68, "MALE", true, USER_ADDRESS, "WHEELCHAIR", ADDED_AT);

        List<PatientRow> patientRows = testDb.patientsOf(appUserId);
        assertThat(patientRows).singleElement().satisfies(patientRow -> {
            assertThat(patientRow.id()).isEqualTo(patientId);
            assertThat(patientRow.mobileCountryCode()).isNull();
            assertThat(patientRow.mobileNumber()).isNull();
            assertThat(patientRow.healthNotes()).isNull();
        });
    }

    @Test
    void idIsGeneratedAndVersionStartsAtZero() {
        UUID patientId = testDb.insertPatient(appUserId, SURESH, true, USER_ADDRESS, ADDED_AT);

        assertThat(patientId).isNotNull();
        assertThat(jdbcTemplate.queryForObject("select version from patients where id = ?", Long.class, patientId))
                .isZero();
    }

    @Test
    void oneUserCanHaveSeveralPatients() {
        testDb.insertPatient(appUserId, SURESH, true, USER_ADDRESS, ADDED_AT);
        testDb.insertPatient(appUserId, "Lata Sharma", true, USER_ADDRESS, ADDED_AT);

        assertThat(testDb.patientsOf(appUserId)).hasSize(2);
    }

    @Test
    void patientForAnUnknownAppUserFails() {
        assertThatThrownBy(() -> testDb.insertPatient(UUID.randomUUID(), SURESH, true, USER_ADDRESS, ADDED_AT))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    // The owner is the app_users row, not the profile: a profile id is not a valid user_id.
    @Test
    void patientOwnedByAProfileIdFails() {
        assertThatThrownBy(() -> testDb.insertPatient(profileId, SURESH, true, USER_ADDRESS, ADDED_AT))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    // User decision 2026-11-24 (B3a review round 1): patients.user_id is on delete cascade.
    @Test
    void deletingTheProfileDeletesItsPatients() {
        testDb.insertPatient(appUserId, SURESH, true, USER_ADDRESS, ADDED_AT);
        testDb.insertPatient(appUserId, "Lata Sharma", true, USER_ADDRESS, ADDED_AT);

        jdbcTemplate.update("delete from profiles where id = ?", profileId);

        assertThat(testDb.count("app_users")).isZero();
        assertThat(testDb.count("patients")).isZero();
    }

    @Test
    void deletingTheAppUserDeletesItsPatients() {
        testDb.insertPatient(appUserId, SURESH, true, USER_ADDRESS, ADDED_AT);

        jdbcTemplate.update("delete from app_users where id = ?", appUserId);

        assertThat(testDb.count("patients")).isZero();
    }

    @Test
    void missingRequiredColumnsFail() {
        assertThatThrownBy(() -> testDb.insertPatient(
                        null, "FATHER", SURESH, 68, "MALE", true, USER_ADDRESS, "WHEELCHAIR", ADDED_AT))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> testDb.insertPatient(
                        appUserId, null, SURESH, 68, "MALE", true, USER_ADDRESS, "WHEELCHAIR", ADDED_AT))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> testDb.insertPatient(
                        appUserId, "FATHER", null, 68, "MALE", true, USER_ADDRESS, "WHEELCHAIR", ADDED_AT))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> testDb.insertPatient(
                        appUserId, "FATHER", SURESH, null, "MALE", true, USER_ADDRESS, "WHEELCHAIR", ADDED_AT))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> testDb.insertPatient(
                        appUserId, "FATHER", SURESH, 68, null, true, USER_ADDRESS, "WHEELCHAIR", ADDED_AT))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> testDb.insertPatient(
                        appUserId, "FATHER", SURESH, 68, "MALE", null, USER_ADDRESS, "WHEELCHAIR", ADDED_AT))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> testDb.insertPatient(
                        appUserId, "FATHER", SURESH, 68, "MALE", true, null, "WHEELCHAIR", ADDED_AT))
                .isInstanceOf(DataIntegrityViolationException.class);
        assertThatThrownBy(() -> testDb.insertPatient(
                        appUserId, "FATHER", SURESH, 68, "MALE", true, USER_ADDRESS, null, ADDED_AT))
                .isInstanceOf(DataIntegrityViolationException.class);

        assertThat(testDb.count("patients")).isZero();
    }

    @Test
    void relationOutsideTheEnumFails() {
        assertThatThrownBy(() -> testDb.insertPatient(
                        appUserId, "BROTHER", SURESH, 68, "MALE", true, USER_ADDRESS, "WHEELCHAIR", ADDED_AT))
                .isInstanceOf(DataAccessException.class)
                .hasMessageContaining("invalid input value for enum relation_type");
    }

    @Test
    void mobilityOutsideTheEnumFails() {
        assertThatThrownBy(() -> testDb.insertPatient(
                        appUserId, "FATHER", SURESH, 68, "MALE", true, USER_ADDRESS, "wheelchair", ADDED_AT))
                .isInstanceOf(DataAccessException.class)
                .hasMessageContaining("invalid input value for enum mobility_category");
    }

    @Test
    void sexOutsideTheEnumFails() {
        assertThatThrownBy(() -> testDb.insertPatient(
                        appUserId, "FATHER", SURESH, 68, "male", true, USER_ADDRESS, "WHEELCHAIR", ADDED_AT))
                .isInstanceOf(DataAccessException.class)
                .hasMessageContaining("invalid input value for enum sex_type");
    }

    // Decision OQ-22: name, age, mobile, address and health-notes rules are validated only in the request DTO.
    @Test
    void patientsHaveNoCheckConstraints() {
        Long checkConstraintCount = jdbcTemplate.queryForObject(
                "select count(*) from pg_constraint where conrelid = 'public.patients'::regclass and contype = 'c'",
                Long.class);

        assertThat(checkConstraintCount).isZero();
    }

    @Test
    void valuesTheDtoRejectsAreStillStorable() {
        testDb.insertPatient(appUserId, "OTHER", "R1", 999, "OTHER", false, "", "BEDRIDDEN", ADDED_AT);

        assertThat(testDb.patientsOf(appUserId)).singleElement().satisfies(patientRow -> {
            assertThat(patientRow.fullName()).isEqualTo("R1");
            assertThat(patientRow.age()).isEqualTo(999);
            assertThat(patientRow.address()).isEmpty();
        });
    }
}
