package com.proxycare.support;

import com.proxycare.features.profile.enums.PreferredLanguage;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;

/** Data setup for integration tests. Tests use real tables; never mock the database. */
public class TestDb {

    private final JdbcTemplate jdbcTemplate;

    public TestDb(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    /** Empties every app table in public, every test_support table, and auth.users. */
    public void truncateAll() {
        List<String> tables = jdbcTemplate.queryForList(
                """
                select format('%I.%I', schemaname, tablename) from pg_tables
                where (schemaname in ('public', 'test_support')
                       and tablename not in ('flyway_schema_history', 'spatial_ref_sys'))
                   or (schemaname = 'auth' and tablename = 'users')
                """,
                String.class);
        jdbcTemplate.execute("truncate table " + String.join(", ", tables) + " cascade");
    }

    public void insertAuthUser(UUID id) {
        jdbcTemplate.update("insert into auth.users (id) values (?)", id);
    }

    /** Inserts the auth.users row and a profile with the given roles (USER, CARETAKER, ADMIN). */
    public void insertProfile(UUID id, String phone, String... roles) {
        insertAuthUser(id);
        jdbcTemplate.update(
                "insert into profiles (id, phone, roles) values (?, ?, ?::app_role[])",
                id,
                phone,
                "{" + String.join(",", roles) + "}");
    }

    public void setPreferredLanguage(UUID profileId, PreferredLanguage preferredLanguage) {
        jdbcTemplate.update(
                "update profiles set preferred_language = ? where id = ?", preferredLanguage.name(), profileId);
    }

    /** The stored roles of a profile, in array order. */
    public List<String> rolesOf(UUID profileId) {
        return jdbcTemplate.queryForList("select unnest(roles)::text from profiles where id = ?", String.class, profileId);
    }

    public String phoneOf(UUID profileId) {
        return jdbcTemplate.queryForObject("select phone from profiles where id = ?", String.class, profileId);
    }

    /** The stored enum name, e.g. "EN". */
    public String preferredLanguageOf(UUID profileId) {
        return jdbcTemplate.queryForObject("select preferred_language from profiles where id = ?", String.class, profileId);
    }

    /** Inserts an app_users row for an existing profile; sex is the enum name (FEMALE, MALE, OTHER). Returns its id. */
    public UUID insertAppUser(UUID profileId, String fullName, String sex, Integer age, String address) {
        return jdbcTemplate.queryForObject(
                """
                insert into app_users (profile_id, full_name, sex, age, address, created_at, updated_at)
                values (?, ?, ?::sex_type, ?::smallint, ?, now(), now())
                returning id
                """,
                UUID.class,
                profileId,
                fullName,
                sex,
                age,
                address);
    }

    /** The stored app_users row of a profile, or null when it has none. */
    public AppUserRow appUserOf(UUID profileId) {
        List<AppUserRow> appUserRows = jdbcTemplate.query(
                "select id, profile_id, full_name, sex::text, age, address from app_users where profile_id = ?",
                (resultSet, rowNumber) -> new AppUserRow(
                        resultSet.getObject("id", UUID.class),
                        resultSet.getObject("profile_id", UUID.class),
                        resultSet.getString("full_name"),
                        resultSet.getString("sex"),
                        resultSet.getObject("age", Integer.class),
                        resultSet.getString("address")),
                profileId);
        return appUserRows.isEmpty() ? null : appUserRows.get(0);
    }

    /** Row count of a table; {@code table} is a literal from test code, e.g. "auth.users". */
    public long count(String table) {
        return jdbcTemplate.queryForObject("select count(*) from " + table, Long.class);
    }
}
