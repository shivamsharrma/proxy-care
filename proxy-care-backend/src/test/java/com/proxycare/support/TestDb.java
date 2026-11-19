package com.proxycare.support;

import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;

/** Data setup for integration tests. Tests use real tables; never mock the database. */
public class TestDb {

    private final JdbcTemplate jdbc;

    public TestDb(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Empties every app table in public, every test_support table, and auth.users. */
    public void truncateAll() {
        List<String> tables = jdbc.queryForList(
                """
                select format('%I.%I', schemaname, tablename) from pg_tables
                where (schemaname in ('public', 'test_support')
                       and tablename not in ('flyway_schema_history', 'spatial_ref_sys'))
                   or (schemaname = 'auth' and tablename = 'users')
                """,
                String.class);
        jdbc.execute("truncate table " + String.join(", ", tables) + " cascade");
    }

    public void insertAuthUser(UUID id) {
        jdbc.update("insert into auth.users (id) values (?)", id);
    }

    /** Row count of a table; {@code table} is a literal from test code, e.g. "auth.users". */
    public long count(String table) {
        return jdbc.queryForObject("select count(*) from " + table, Long.class);
    }
}
