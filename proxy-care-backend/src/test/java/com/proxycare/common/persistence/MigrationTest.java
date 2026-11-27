package com.proxycare.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.proxycare.support.IntegrationTest;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.JdbcTemplate;

class MigrationTest extends IntegrationTest {

    @Autowired
    JdbcTemplate jdbcTemplate;

    @Test
    void appMigrationsAppliedSuccessfully() {
        List<String> appliedVersions = jdbcTemplate.queryForList(
                """
                select version from flyway_schema_history
                where success and version in ('1', '2', '3', '4', '5') order by installed_rank
                """,
                String.class);

        assertThat(appliedVersions).containsExactly("1", "2", "3", "4", "5");
    }

    // Allowed values are validated in request DTOs, not by DB checks.
    @Test
    void profilesHaveNoPreferredLanguageCheck() {
        Long appliedCount = jdbcTemplate.queryForObject(
                "select count(*) from flyway_schema_history where success and version = '3'", Long.class);
        Long languageCheckCount = jdbcTemplate.queryForObject(
                """
                select count(*) from pg_constraint
                where conrelid = 'public.profiles'::regclass and conname = 'profiles_preferred_language_check'
                """,
                Long.class);

        assertThat(appliedCount).isEqualTo(1);
        assertThat(languageCheckCount).isZero();
    }

    @Test
    void profilesDefaultToTheEnglishEnumName() {
        UUID id = UUID.randomUUID();

        testDb.insertProfile(id, "+919876543210", "USER");

        assertThat(testDb.preferredLanguageOf(id)).isEqualTo("EN");
    }

    @Test
    void profilesStartAtVersionZero() {
        UUID id = UUID.randomUUID();

        testDb.insertProfile(id, "+919876543210", "USER");

        assertThat(jdbcTemplate.queryForObject("select version from profiles where id = ?", Long.class, id))
                .isZero();
    }

    @Test
    void appUsersMigrationApplied() {
        Long appliedCount = jdbcTemplate.queryForObject(
                "select count(*) from flyway_schema_history where success and version = '6'", Long.class);

        assertThat(appliedCount).isEqualTo(1);
    }

    @Test
    void appUsersHaveTheBaseEntityAndProfileColumns() {
        List<String> appUserColumns = jdbcTemplate.queryForList(
                """
                select column_name || ' ' || udt_name || ' ' || is_nullable from information_schema.columns
                where table_schema = 'public' and table_name = 'app_users'
                """,
                String.class);

        assertThat(appUserColumns).containsExactlyInAnyOrder(
                "id uuid NO",
                "created_at timestamptz NO",
                "updated_at timestamptz NO",
                "version int8 NO",
                "profile_id uuid NO",
                "full_name text NO",
                "sex text NO",
                "age int2 YES",
                "address text NO");
    }

    @Test
    void patientsMigrationApplied() {
        Long appliedCount = jdbcTemplate.queryForObject(
                "select count(*) from flyway_schema_history where success and version = '7'", Long.class);

        assertThat(appliedCount).isEqualTo(1);
    }

    // 05_add_family_member.feature: the "Lives at my address" toggle was removed; every patient has its own address.
    @Test
    void patientsDropLivesAtUserAddressMigrationApplied() {
        Long appliedCount = jdbcTemplate.queryForObject(
                "select count(*) from flyway_schema_history where success and version = '8'", Long.class);

        assertThat(appliedCount).isEqualTo(1);
    }

    // Columns are named after their type: the MobilityCategory field is mobilityCategory, its column mobility_category.
    @Test
    void patientsRenameMobilityMigrationApplied() {
        Long appliedCount = jdbcTemplate.queryForObject(
                "select count(*) from flyway_schema_history where success and version = '9'", Long.class);

        assertThat(appliedCount).isEqualTo(1);
    }

    @Test
    void patientsHaveTheBaseEntityAndPatientColumns() {
        List<String> patientColumns = jdbcTemplate.queryForList(
                """
                select column_name || ' ' || udt_name || ' ' || is_nullable from information_schema.columns
                where table_schema = 'public' and table_name = 'patients'
                """,
                String.class);

        assertThat(patientColumns).containsExactlyInAnyOrder(
                "id uuid NO",
                "created_at timestamptz NO",
                "updated_at timestamptz NO",
                "version int8 NO",
                "user_id uuid NO",
                "relation text NO",
                "full_name text NO",
                "age int2 NO",
                "sex text NO",
                "mobile_country_code text YES",
                "mobile_number text YES",
                "address text NO",
                "mobility_category text NO",
                "health_notes text YES",
                "deleted_at timestamptz YES");
    }

    // The family list reads live patients by owner, so the index skips soft-deleted rows.
    @Test
    void patientsUserIndexCoversOnlyLivePatients() {
        List<String> indexDefinitions = jdbcTemplate.queryForList(
                "select indexdef from pg_indexes where schemaname = 'public' and indexname = 'patients_user_idx'",
                String.class);

        assertThat(indexDefinitions).singleElement().satisfies(indexDefinition -> assertThat(indexDefinition)
                .contains("ON public.patients")
                .contains("(user_id)")
                .contains("WHERE (deleted_at IS NULL)"));
    }

    @Test
    void enumsAsTextMigrationApplied() {
        Long appliedCount = jdbcTemplate.queryForObject(
                "select count(*) from flyway_schema_history where success and version = '10'", Long.class);

        assertThat(appliedCount).isEqualTo(1);
    }

    // User decision 2026-11-26: enums are stored as text by their Java names (@Enumerated(STRING)), never as
    // Postgres enum types.
    @Test
    void publicSchemaHasNoEnumTypes() {
        Long enumTypeCount = jdbcTemplate.queryForObject(
                """
                select count(*) from pg_type t join pg_namespace n on n.oid = t.typnamespace
                where n.nspname = 'public' and t.typtype = 'e'
                """,
                Long.class);

        assertThat(enumTypeCount).isZero();
    }

    @Test
    void caretakersMigrationApplied() {
        Long appliedCount = jdbcTemplate.queryForObject(
                "select count(*) from flyway_schema_history where success and version = '11'", Long.class);

        assertThat(appliedCount).isEqualTo(1);
    }

    // bank_verification_status is null until the payout account is first submitted.
    @Test
    void caretakersHaveTheBaseEntityAndStatusColumns() {
        List<String> caretakerColumns = jdbcTemplate.queryForList(
                """
                select column_name || ' ' || udt_name || ' ' || is_nullable from information_schema.columns
                where table_schema = 'public' and table_name = 'caretakers'
                """,
                String.class);

        assertThat(caretakerColumns).containsExactlyInAnyOrder(
                "id uuid NO",
                "created_at timestamptz NO",
                "updated_at timestamptz NO",
                "version int8 NO",
                "profile_id uuid NO",
                "status text NO",
                "onboarding_status text NO",
                "video_verification_status text NO",
                "bank_verification_status text YES",
                "kyc_step int2 NO",
                "rejected_reason text YES");
    }

    // Decision OQ-22: value rules live in the API only.
    @Test
    void caretakersHaveNoCheckConstraints() {
        Long checkConstraintCount = jdbcTemplate.queryForObject(
                "select count(*) from pg_constraint where conrelid = 'public.caretakers'::regclass and contype = 'c'",
                Long.class);

        assertThat(checkConstraintCount).isZero();
    }

    @Test
    void aProfileHasAtMostOneCaretakerRow() {
        UUID profileId = UUID.randomUUID();
        testDb.insertProfile(profileId, "+919988776655", "CARETAKER");
        testDb.insertOnboardingCaretaker(profileId, 2);

        assertThatThrownBy(() -> testDb.insertOnboardingCaretaker(profileId, 2))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void deletingTheProfileDeletesTheCaretaker() {
        UUID profileId = UUID.randomUUID();
        testDb.insertProfile(profileId, "+919988776655", "CARETAKER");
        testDb.insertOnboardingCaretaker(profileId, 2);

        jdbcTemplate.update("delete from profiles where id = ?", profileId);

        assertThat(testDb.count("caretakers")).isZero();
    }

    @Test
    void profileRolesAreATextArray() {
        String rolesType = jdbcTemplate.queryForObject(
                """
                select udt_name from information_schema.columns
                where table_schema = 'public' and table_name = 'profiles' and column_name = 'roles'
                """,
                String.class);

        assertThat(rolesType).isEqualTo("_text");
    }

    @Test
    void postgisExtensionExists() {
        assertThat(jdbcTemplate.queryForObject("select count(*) from pg_extension where extname = 'postgis'", Long.class))
                .isEqualTo(1);
    }
}
