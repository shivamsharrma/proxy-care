package com.proxycare.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.support.IntegrationTest;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
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
    void sexTypeHoldsTheSexEnumNames() {
        List<String> sexTypeLabels = jdbcTemplate.queryForList(
                """
                select e.enumlabel from pg_enum e join pg_type t on t.oid = e.enumtypid
                where t.typname = 'sex_type' order by e.enumsortorder
                """,
                String.class);

        assertThat(sexTypeLabels).containsExactly("FEMALE", "MALE", "OTHER");
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
                "sex sex_type NO",
                "age int2 YES",
                "address text NO");
    }

    @Test
    void patientsMigrationApplied() {
        Long appliedCount = jdbcTemplate.queryForObject(
                "select count(*) from flyway_schema_history where success and version = '7'", Long.class);

        assertThat(appliedCount).isEqualTo(1);
    }

    // 05_add_family_member.feature: Each relation is saved with the right enum.
    @Test
    void relationTypeHoldsTheRelationEnumNames() {
        List<String> relationTypeLabels = jdbcTemplate.queryForList(
                """
                select e.enumlabel from pg_enum e join pg_type t on t.oid = e.enumtypid
                where t.typname = 'relation_type' order by e.enumsortorder
                """,
                String.class);

        assertThat(relationTypeLabels).containsExactly("FATHER", "MOTHER", "SPOUSE", "GRANDPARENT", "SIBLING", "OTHER");
    }

    // 05_add_family_member.feature: Each mobility category is saved with the right enum.
    @Test
    void mobilityCategoryHoldsTheMobilityEnumNames() {
        List<String> mobilityCategoryLabels = jdbcTemplate.queryForList(
                """
                select e.enumlabel from pg_enum e join pg_type t on t.oid = e.enumtypid
                where t.typname = 'mobility_category' order by e.enumsortorder
                """,
                String.class);

        assertThat(mobilityCategoryLabels).containsExactly("AMBULATORY", "WHEELCHAIR", "BEDRIDDEN");
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
                "relation relation_type NO",
                "full_name text NO",
                "age int2 NO",
                "sex sex_type NO",
                "mobile_country_code text YES",
                "mobile_number text YES",
                "lives_at_user_address bool NO",
                "address text NO",
                "mobility mobility_category NO",
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
    void postgisExtensionExists() {
        assertThat(jdbcTemplate.queryForObject("select count(*) from pg_extension where extname = 'postgis'", Long.class))
                .isEqualTo(1);
    }
}
