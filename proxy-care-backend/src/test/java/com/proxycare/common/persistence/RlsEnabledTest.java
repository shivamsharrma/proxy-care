package com.proxycare.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.support.IntegrationTest;
import java.util.Map;
import java.util.TreeMap;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

/** Guards every future migration: each app table in public must have RLS on (deny-all for the anon key). */
class RlsEnabledTest extends IntegrationTest {

    @Autowired
    JdbcTemplate jdbcTemplate;

    @Test
    void everyPublicTableHasRowLevelSecurity() {
        Map<String, Boolean> rls = new TreeMap<>();
        jdbcTemplate.query(
                """
                select c.relname, c.relrowsecurity from pg_class c
                join pg_namespace n on n.oid = c.relnamespace
                where n.nspname = 'public' and c.relkind in ('r', 'p')
                  and c.relname not in ('flyway_schema_history', 'spatial_ref_sys')
                """,
                rs -> {
                    rls.put(rs.getString(1), rs.getBoolean(2));
                });

        assertThat(rls).containsKeys("profiles", "app_users", "patients", "caretakers");
        assertThat(rls).allSatisfy((table, enabled) -> assertThat(enabled).as("RLS on %s", table).isTrue());
    }

    // The caretaker-photos Storage policies live in the storage schema, so they are not counted here.
    @Test
    void noPublicTableHasAPolicy() {
        Long policyCount = jdbcTemplate.queryForObject(
                "select count(*) from pg_policies where schemaname = 'public'", Long.class);

        assertThat(policyCount).isZero();
    }
}
