package com.proxycare.common.persistence;

import static org.assertj.core.api.Assertions.assertThat;

import com.proxycare.support.IntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

class MigrationTest extends IntegrationTest {

    @Autowired
    JdbcTemplate jdbc;

    @Test
    void appMigrationsAppliedSuccessfully() {
        var applied = jdbc.queryForList(
                "select version from flyway_schema_history where success and version in ('1', '2') order by installed_rank",
                String.class);

        assertThat(applied).containsExactly("1", "2");
    }

    @Test
    void postgisExtensionExists() {
        assertThat(jdbc.queryForObject("select count(*) from pg_extension where extname = 'postgis'", Long.class))
                .isEqualTo(1);
    }
}
