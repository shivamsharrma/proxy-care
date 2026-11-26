package com.proxycare.support;

import com.proxycare.features.profile.enums.PreferredLanguage;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;

/** Data setup for integration tests. Tests use real tables; never mock the database. */
public class TestDb {

    private static final String PATIENT_ROW_SELECT = """
            select id, user_id, relation, full_name, age, sex, mobile_country_code, mobile_number,
                   address, mobility_category, health_notes, deleted_at
            from patients""";

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
                "insert into profiles (id, phone, roles) values (?, ?, ?::text[])",
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
        return jdbcTemplate.queryForList("select unnest(roles) from profiles where id = ?", String.class, profileId);
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
                values (?, ?, ?, ?::smallint, ?, now(), now())
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
                "select id, profile_id, full_name, sex, age, address from app_users where profile_id = ?",
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

    /**
     * Inserts a live patients row for an existing app_users row, without mobile or health notes. relation, sex and
     * mobilityCategory are the enum names (FATHER, MALE, WHEELCHAIR). A null argument is stored as null.
     * Returns its id.
     */
    public UUID insertPatient(
            UUID appUserId,
            String relation,
            String fullName,
            Integer age,
            String sex,
            String address,
            String mobilityCategory,
            Instant createdAt) {
        OffsetDateTime createdAtUtc = OffsetDateTime.ofInstant(createdAt, ZoneOffset.UTC);
        return jdbcTemplate.queryForObject(
                """
                insert into patients (user_id, relation, full_name, age, sex, address, mobility_category, created_at,
                                      updated_at)
                values (?, ?, ?, ?::smallint, ?, ?, ?, ?, ?)
                returning id
                """,
                UUID.class,
                appUserId,
                relation,
                fullName,
                age,
                sex,
                address,
                mobilityCategory,
                createdAtUtc,
                createdAtUtc);
    }

    /** Inserts a valid live patient (FATHER, 68, MALE, WHEELCHAIR) added at {@code createdAt}. */
    public UUID insertPatient(UUID appUserId, String fullName, String address, Instant createdAt) {
        return insertPatient(appUserId, "FATHER", fullName, 68, "MALE", address, "WHEELCHAIR", createdAt);
    }

    public void softDeletePatient(UUID patientId, Instant deletedAt) {
        jdbcTemplate.update(
                "update patients set deleted_at = ? where id = ?",
                OffsetDateTime.ofInstant(deletedAt, ZoneOffset.UTC),
                patientId);
    }

    /** The stored patients rows of an app_users row (soft-deleted included), oldest first. */
    public List<PatientRow> patientsOf(UUID appUserId) {
        return jdbcTemplate.query(
                PATIENT_ROW_SELECT + " where user_id = ? order by created_at, id", TestDb::toPatientRow, appUserId);
    }

    /** The stored patients row with this id (soft-deleted included), or null when there is none. */
    public PatientRow patient(UUID patientId) {
        List<PatientRow> patientRows =
                jdbcTemplate.query(PATIENT_ROW_SELECT + " where id = ?", TestDb::toPatientRow, patientId);
        return patientRows.isEmpty() ? null : patientRows.get(0);
    }

    private static PatientRow toPatientRow(ResultSet resultSet, int rowNumber) throws SQLException {
        return new PatientRow(
                resultSet.getObject("id", UUID.class),
                resultSet.getObject("user_id", UUID.class),
                resultSet.getString("relation"),
                resultSet.getString("full_name"),
                resultSet.getObject("age", Integer.class),
                resultSet.getString("sex"),
                resultSet.getString("mobile_country_code"),
                resultSet.getString("mobile_number"),
                resultSet.getString("address"),
                resultSet.getString("mobility_category"),
                resultSet.getString("health_notes"),
                toInstant(resultSet.getObject("deleted_at", OffsetDateTime.class)));
    }

    private static Instant toInstant(OffsetDateTime offsetDateTime) {
        return offsetDateTime == null ? null : offsetDateTime.toInstant();
    }

    /** Row count of a table; {@code table} is a literal from test code, e.g. "auth.users". */
    public long count(String table) {
        return jdbcTemplate.queryForObject("select count(*) from " + table, Long.class);
    }
}
