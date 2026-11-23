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
    void postgisExtensionExists() {
        assertThat(jdbcTemplate.queryForObject("select count(*) from pg_extension where extname = 'postgis'", Long.class))
                .isEqualTo(1);
    }
}
